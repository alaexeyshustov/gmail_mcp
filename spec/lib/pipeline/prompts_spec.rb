require_relative '../../spec_helper'

RSpec.describe Pipeline::Prompts do
  subject(:prompts) do
    described_class.new(
      application_csv: '/tmp/applications.csv',
      interviews_csv:  '/tmp/interviews.csv'
    )
  end

  describe '#build_init_message' do
    it 'references the application CSV path' do
      expect(prompts.build_init_message).to include('/tmp/applications.csv')
    end

    it 'instructs the agent to return JSON with latest_date and existing_ids' do
      msg = prompts.build_init_message
      expect(msg).to include('latest_date')
      expect(msg).to include('existing_ids')
    end
  end

  describe '#build_fetch_message' do
    it 'includes provider and after_date' do
      msg = prompts.build_fetch_message('gmail', '2026-03-01')
      expect(msg).to include('gmail')
      expect(msg).to include('2026-03-01')
    end

    it 'omits before_date when not given' do
      msg = prompts.build_fetch_message('gmail', '2026-03-01')
      expect(msg).not_to include('before_date')
    end

    it 'includes before_date when provided' do
      msg = prompts.build_fetch_message('gmail', '2026-03-01', '2026-03-02')
      expect(msg).to include('before_date')
      expect(msg).to include('2026-03-02')
    end

    it 'instructs the agent to return a JSON array' do
      expect(prompts.build_fetch_message('yahoo', '2026-03-01')).to include('JSON array')
    end
  end

  describe '#build_label_store_message' do
    let(:batch) { [{ 'id' => '1', 'subject' => 'Job offer' }] }

    it 'references the application CSV path' do
      expect(prompts.build_label_store_message(batch)).to include('/tmp/applications.csv')
    end

    it 'embeds the batch JSON' do
      msg = prompts.build_label_store_message(batch)
      expect(msg).to include('Job offer')
    end
  end

  describe '#build_reconcile_message' do
    let(:added_rows) { [{ 'company' => 'Acme', 'job_title' => 'Engineer' }] }

    it 'references the interviews CSV path' do
      expect(prompts.build_reconcile_message(added_rows)).to include('/tmp/interviews.csv')
    end

    it 'embeds the added rows JSON' do
      msg = prompts.build_reconcile_message(added_rows)
      expect(msg).to include('Acme')
    end
  end
end
