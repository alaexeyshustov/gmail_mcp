require_relative '../../spec_helper'
require 'json'
require 'tmpdir'

RSpec.describe Pipeline::JobsWorkflow do
  let(:mcp_tools) do
    %w[list_emails get_email search_emails get_labels get_unread_count
       add_labels classify_emails manage_csv].map { |n| FakeMcpTool.new(n) }
  end
  let(:mcp_connection) { Struct.new(:tools).new(mcp_tools) }

  before do
    RubyLLM.configure { |c| c.mistral_api_key = 'test-key' }
    # Pin today so day_batches always produces a single range (diff == 1)
    # regardless of when the suite runs. Cassettes record latest_date as
    # 2026-03-10, so diff = (2026-03-11 - 2026-03-10) = 1.
    allow(Date).to receive(:today).and_return(Date.new(2026, 3, 11))
  end

  subject(:workflow) { described_class.new(mcp_connection: mcp_connection, model: 'mistral-large-latest') }

  # ---------------------------------------------------------------------------
  # tools_for — pure unit tests, no HTTP
  # ---------------------------------------------------------------------------
  describe '#tools_for (private)' do
    it 'returns only manage_csv for InitDatabaseAgent' do
      expect(workflow.send(:tools_for, Pipeline::Agents::InitDatabaseAgent).map(&:name))
        .to eq(%w[manage_csv])
    end

    it 'returns only list_emails for EmailFetchAgent' do
      expect(workflow.send(:tools_for, Pipeline::Agents::EmailFetchAgent).map(&:name))
        .to eq(%w[list_emails])
    end

    it 'returns only classify_emails for ClassifyAndFilterAgent' do
      expect(workflow.send(:tools_for, Pipeline::Agents::ClassifyAndFilterAgent).map(&:name))
        .to eq(%w[classify_emails])
    end

    it 'returns add_labels and manage_csv for LabelAndStoreAgent' do
      expect(workflow.send(:tools_for, Pipeline::Agents::LabelAndStoreAgent).map(&:name))
        .to contain_exactly('add_labels', 'manage_csv')
    end

    it 'returns only manage_csv for ReconcileInterviewsAgent' do
      expect(workflow.send(:tools_for, Pipeline::Agents::ReconcileInterviewsAgent).map(&:name))
        .to eq(%w[manage_csv])
    end
  end

  # ---------------------------------------------------------------------------
  # #run — integration tests backed by VCR cassettes
  # ---------------------------------------------------------------------------
  describe '#run' do
    context 'happy path (3 new emails, 3 job emails, 3 stored rows)' do
      it 'returns a complete result hash with correct counts' do
        VCR.use_cassette('workflow/happy_path') do
          result = workflow.run
          expect(result[:status]).to eq('complete')
          expect(result[:new_emails]).to eq(3)
          expect(result[:job_emails]).to eq(3)
          expect(result[:rows_added]).to eq(3)
          expect(result[:reconcile_summaries]).to all(be_a(String))
        end
      end

      it 'calls agent classes in the correct pipeline order: Init → Fetch×2 → Classify → LabelStore → Reconcile' do
        order = []
        [
          Pipeline::Agents::InitDatabaseAgent,
          Pipeline::Agents::EmailFetchAgent,
          Pipeline::Agents::ClassifyAndFilterAgent,
          Pipeline::Agents::LabelAndStoreAgent,
          Pipeline::Agents::ReconcileInterviewsAgent
        ].each do |klass|
          allow(klass).to receive(:new).and_wrap_original { |m| order << klass; m.call }
        end

        VCR.use_cassette('workflow/happy_path') { workflow.run }

        fetch_indices    = order.each_index.select { |i| order[i] == Pipeline::Agents::EmailFetchAgent }
        classify_index   = order.index(Pipeline::Agents::ClassifyAndFilterAgent)
        label_index      = order.index(Pipeline::Agents::LabelAndStoreAgent)
        reconcile_index  = order.index(Pipeline::Agents::ReconcileInterviewsAgent)

        expect(order.first).to eq(Pipeline::Agents::InitDatabaseAgent)
        expect(fetch_indices.size).to eq(2)
        expect(fetch_indices.max).to be < classify_index
        expect(classify_index).to be < label_index
        expect(label_index).to be < reconcile_index
      end

      it 'creates a fresh agent instance for each invocation' do
        counts = Hash.new(0)
        [
          Pipeline::Agents::InitDatabaseAgent,
          Pipeline::Agents::EmailFetchAgent,
          Pipeline::Agents::ClassifyAndFilterAgent,
          Pipeline::Agents::LabelAndStoreAgent,
          Pipeline::Agents::ReconcileInterviewsAgent
        ].each do |klass|
          allow(klass).to receive(:new).and_wrap_original { |m| counts[klass] += 1; m.call }
        end

        VCR.use_cassette('workflow/happy_path') { workflow.run }

        expect(counts[Pipeline::Agents::InitDatabaseAgent]).to eq(1)
        expect(counts[Pipeline::Agents::EmailFetchAgent]).to eq(2) # gmail + yahoo in the single day batch
        expect(counts[Pipeline::Agents::ClassifyAndFilterAgent]).to eq(1)
        expect(counts[Pipeline::Agents::LabelAndStoreAgent]).to eq(1)
        expect(counts[Pipeline::Agents::ReconcileInterviewsAgent]).to eq(1)
      end

      it 'applies the configured model to every agent instance' do
        applied = []
        [
          Pipeline::Agents::InitDatabaseAgent,
          Pipeline::Agents::EmailFetchAgent,
          Pipeline::Agents::ClassifyAndFilterAgent,
          Pipeline::Agents::LabelAndStoreAgent,
          Pipeline::Agents::ReconcileInterviewsAgent
        ].each do |klass|
          allow_any_instance_of(klass).to receive(:with_model).and_wrap_original do |m, model_id|
            applied << model_id
            m.call(model_id)
          end
        end

        VCR.use_cassette('workflow/happy_path') { workflow.run }

        expect(applied).to all(eq('mistral-large-latest'))
        expect(applied.size).to eq(6) # init + fetch×2 + classify + label + reconcile (single day)
      end
    end

    context 'when no model is configured' do
      subject(:workflow) { described_class.new(mcp_connection: mcp_connection) }

      it 'applies the first pool model (mistral-large-latest) to every agent' do
        applied = []
        [
          Pipeline::Agents::InitDatabaseAgent,
          Pipeline::Agents::EmailFetchAgent,
          Pipeline::Agents::ClassifyAndFilterAgent,
          Pipeline::Agents::LabelAndStoreAgent,
          Pipeline::Agents::ReconcileInterviewsAgent
        ].each do |klass|
          allow_any_instance_of(klass).to receive(:with_model).and_wrap_original do |m, model_id|
            applied << model_id
            m.call(model_id)
          end
        end

        VCR.use_cassette('workflow/happy_path') { workflow.run }

        expect(applied).to all(eq(Pipeline::JobsWorkflow::MODELS_POOL.first))
      end
    end

    context 'when all fetched emails already exist in the database' do
      it 'returns { status: "no_new_emails" } without calling downstream agents' do
        VCR.use_cassette('workflow/no_new_emails') do
          result = workflow.run
          expect(result).to eq({ status: 'no_new_emails' })
        end
      end

      it 'does not instantiate ClassifyAndFilterAgent' do
        expect(Pipeline::Agents::ClassifyAndFilterAgent).not_to receive(:new)
        VCR.use_cassette('workflow/no_new_emails') { workflow.run }
      end
    end

    context 'when classification returns no job-related emails' do
      it 'returns { status: "no_job_emails" } without calling LabelAndStoreAgent' do
        VCR.use_cassette('workflow/no_job_emails') do
          result = workflow.run
          expect(result).to eq({ status: 'no_job_emails' })
        end
      end

      it 'does not instantiate LabelAndStoreAgent' do
        expect(Pipeline::Agents::LabelAndStoreAgent).not_to receive(:new)
        VCR.use_cassette('workflow/no_job_emails') { workflow.run }
      end
    end

    context 'with more than BATCH_SIZE (15) emails' do
      it 'processes emails in two batches and returns rows_added == 30' do
        VCR.use_cassette('workflow/large_batches') do
          result = workflow.run
          expect(result[:status]).to eq('complete')
          expect(result[:rows_added]).to eq(30)
        end
      end

      it 'instantiates LabelAndStoreAgent twice (once per batch)' do
        count = 0
        allow(Pipeline::Agents::LabelAndStoreAgent).to receive(:new).and_wrap_original { |m| count += 1; m.call }

        VCR.use_cassette('workflow/large_batches') { workflow.run }

        expect(count).to eq(2)
      end
    end

    context 'when some fetched emails are already in the database (deduplication)' do
      it 'counts only genuinely new emails in the result' do
        VCR.use_cassette('workflow/deduplication') do
          result = workflow.run
          expect(result[:status]).to eq('complete')
          expect(result[:new_emails]).to eq(2)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #ensure_csv_files_exist — pure unit tests, no HTTP
  # ---------------------------------------------------------------------------
  describe '#ensure_csv_files_exist (private)' do
    it 'creates both CSV files with headers when neither exists' do
      Dir.mktmpdir do |dir|
        app_csv  = File.join(dir, 'application_mails.csv')
        int_csv  = File.join(dir, 'interviews.csv')

        stub_const('Pipeline::JobsWorkflow::APPLICATION_CSV', app_csv)
        stub_const('Pipeline::JobsWorkflow::INTERVIEWS_CSV',  int_csv)

        workflow.send(:ensure_csv_files_exist)

        expect(File.exist?(app_csv)).to be true
        expect(CSV.read(app_csv, headers: true).headers)
          .to eq(Pipeline::JobsWorkflow::APPLICATION_CSV_HEADERS)

        expect(File.exist?(int_csv)).to be true
        expect(CSV.read(int_csv, headers: true).headers)
          .to eq(Pipeline::JobsWorkflow::INTERVIEWS_CSV_HEADERS)
      end
    end

    it 'does not overwrite an existing CSV file' do
      Dir.mktmpdir do |dir|
        app_csv = File.join(dir, 'application_mails.csv')
        int_csv = File.join(dir, 'interviews.csv')

        File.write(app_csv, "col1,col2\nv1,v2\n")
        File.write(int_csv, "col1\nv1\n")

        stub_const('Pipeline::JobsWorkflow::APPLICATION_CSV', app_csv)
        stub_const('Pipeline::JobsWorkflow::INTERVIEWS_CSV',  int_csv)

        workflow.send(:ensure_csv_files_exist)

        expect(File.read(app_csv)).to eq("col1,col2\nv1,v2\n")
        expect(File.read(int_csv)).to eq("col1\nv1\n")
      end
    end

    it 'creates parent directories when they do not exist' do
      Dir.mktmpdir do |dir|
        app_csv = File.join(dir, 'nested', 'deep', 'app.csv')
        int_csv = File.join(dir, 'nested', 'deep', 'int.csv')

        stub_const('Pipeline::JobsWorkflow::APPLICATION_CSV', app_csv)
        stub_const('Pipeline::JobsWorkflow::INTERVIEWS_CSV',  int_csv)

        expect { workflow.send(:ensure_csv_files_exist) }.not_to raise_error
        expect(File.exist?(app_csv)).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #days_to_process — pure unit tests, no HTTP
  # ---------------------------------------------------------------------------
  describe '#days_to_process (private)' do
    let(:today) { Date.parse('2026-03-10') }

    before { allow(Date).to receive(:today).and_return(today) }

    it 'returns a single date when diff is 0 (cutoff == today)' do
      expect(workflow.send(:days_to_process, '2026-03-10')).to eq(['2026-03-10'])
    end

    it 'returns a single date when diff is 1' do
      expect(workflow.send(:days_to_process, '2026-03-09')).to eq(['2026-03-09'])
    end

    it 'returns 2 dates when diff is exactly 2' do
      expect(workflow.send(:days_to_process, '2026-03-08')).to eq(['2026-03-08', '2026-03-09'])
    end

    it 'returns N dates when diff is N >= 2' do
      expect(workflow.send(:days_to_process, '2026-03-07')).to eq(['2026-03-07', '2026-03-08', '2026-03-09'])
    end
  end

  # ---------------------------------------------------------------------------
  # #effective_models_pool — pure unit tests, no HTTP
  # ---------------------------------------------------------------------------
  describe '#effective_models_pool (private)' do
    it 'returns MODELS_POOL when no model is configured' do
      wf = described_class.new(mcp_connection: mcp_connection)
      expect(wf.send(:effective_models_pool)).to eq(Pipeline::JobsWorkflow::MODELS_POOL)
    end

    it 'places the configured model first when it is already in the pool' do
      wf = described_class.new(mcp_connection: mcp_connection, model: 'gpt-5.1')
      pool = wf.send(:effective_models_pool)
      expect(pool.first).to eq('gpt-5.1')
      expect(pool.count('gpt-5.1')).to eq(1)
    end

    it 'places the configured model first and appends remaining pool entries' do
      wf = described_class.new(mcp_connection: mcp_connection, model: 'mistral-large-latest')
      expect(wf.send(:effective_models_pool))
        .to eq(['mistral-large-latest', 'gpt-5.1'])
    end

    it 'places a custom model first and keeps the full pool after it' do
      wf = described_class.new(mcp_connection: mcp_connection, model: 'custom-model')
      pool = wf.send(:effective_models_pool)
      expect(pool.first).to eq('custom-model')
      expect(pool).to include(*Pipeline::JobsWorkflow::MODELS_POOL)
    end
  end

  # ---------------------------------------------------------------------------
  # #run_agent — rate-limit / model-switching unit tests, no HTTP
  # ---------------------------------------------------------------------------
  describe '#run_agent (private)' do
    let(:agent_double) { instance_double(Pipeline::Agents::InitDatabaseAgent) }
    let(:response_double) { instance_double(RubyLLM::Message, content: '{"latest_date":"2026-03-10","existing_ids":[]}') }

    before do
      allow(Pipeline::Agents::InitDatabaseAgent).to receive(:new).and_return(agent_double)
      allow(agent_double).to receive(:with_model)
      allow(agent_double).to receive(:with_tools)
    end

    it 'uses with_model with the first pool model' do
      allow(agent_double).to receive(:ask).and_return(response_double)
      workflow.send(:run_agent, Pipeline::Agents::InitDatabaseAgent, 'msg')
      expect(agent_double).to have_received(:with_model).with('mistral-large-latest')
    end

    it 'retries with same model and backoff on first rate-limit error' do
      call_count = 0
      allow(agent_double).to receive(:ask) do
        call_count += 1
        raise RubyLLM::RateLimitError if call_count == 1

        response_double
      end
      allow(workflow).to receive(:sleep)

      workflow.send(:run_agent, Pipeline::Agents::InitDatabaseAgent, 'msg')

      expect(workflow).to have_received(:sleep).with(Pipeline::JobsWorkflow::RATE_LIMIT_BASE_DELAY)
      expect(agent_double).to have_received(:with_model).with('mistral-large-latest').twice
    end

    it 'switches to the next pool model after RATE_LIMIT_SWITCH_AFTER retries' do
      call_count = 0
      allow(agent_double).to receive(:ask) do
        call_count += 1
        raise RubyLLM::RateLimitError if call_count <= Pipeline::JobsWorkflow::RATE_LIMIT_SWITCH_AFTER + 1

        response_double
      end
      allow(workflow).to receive(:sleep)

      workflow.send(:run_agent, Pipeline::Agents::InitDatabaseAgent, 'msg')

      expect(agent_double).to have_received(:with_model).with('mistral-large-latest')
        .exactly(Pipeline::JobsWorkflow::RATE_LIMIT_SWITCH_AFTER + 1).times
      expect(agent_double).to have_received(:with_model).with('gpt-5.1').at_least(:once)
    end

    it 're-raises when all pool models are exhausted' do
      allow(agent_double).to receive(:ask).and_raise(RubyLLM::RateLimitError)
      allow(workflow).to receive(:sleep)

      expect do
        workflow.send(:run_agent, Pipeline::Agents::InitDatabaseAgent, 'msg')
      end.to raise_error(RubyLLM::RateLimitError)
    end
  end

  # ---------------------------------------------------------------------------
  # Logger injection
  # ---------------------------------------------------------------------------
  describe 'logger integration' do
    let(:log_output) { StringIO.new }
    let(:logger)     { Pipeline::Logger.new(level: :debug, output: log_output) }

    subject(:workflow) do
      described_class.new(mcp_connection: mcp_connection, model: 'mistral-large-latest', logger: logger)
    end

    it 'accepts a custom logger and writes step banners at INFO level' do
      VCR.use_cassette('workflow/happy_path') { workflow.run }
      output = log_output.string
      expect(output).to include('Step 1')
      expect(output).to include('Step 2')
      expect(output).to include('Step 3')
      expect(output).to include('Step 4')
      expect(output).to include('Step 5')
    end

    it 'emits DEBUG detail lines when level is :debug' do
      VCR.use_cassette('workflow/happy_path') { workflow.run }
      output = log_output.string
      # detail lines: fetched N emails, cutoff_date, new emails, job emails, rows added
      expect(output).to include('cutoff_date=')
      expect(output).to include('total emails')
      expect(output).to include('new emails after deduplication')
    end

    context 'with info-level logger' do
      let(:logger) { Pipeline::Logger.new(level: :info, output: log_output) }

      it 'suppresses DEBUG detail lines' do
        VCR.use_cassette('workflow/happy_path') { workflow.run }
        output = log_output.string
        expect(output).not_to include('cutoff_date=')
        expect(output).not_to include('total emails')
      end

      it 'still emits step banners' do
        VCR.use_cassette('workflow/happy_path') { workflow.run }
        expect(log_output.string).to include('Step 1').and include('Step 5')
      end
    end

    context 'with default logger (no logger: kwarg)' do
      subject(:workflow) do
        described_class.new(mcp_connection: mcp_connection, model: 'mistral-large-latest')
      end

      it 'does not raise' do
        expect do
          VCR.use_cassette('workflow/happy_path') { workflow.run }
        end.not_to raise_error
      end
    end
  end
end
