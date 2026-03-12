require 'date'
require 'csv'
require 'fileutils'
require 'json'
require 'async'
require 'async/semaphore'

module Pipeline
  # Sequential multi-agent workflow for job application email tracking.
  #
  # Follows the Sequential Workflow pattern:
  # https://rubyllm.com/agentic-workflows/
  #
  # Each step produces structured output that the next step consumes.
  # Ruby code handles data transformation between agents; no LLM call is wasted
  # on work that can be done deterministically.
  #
  # When the gap between the database cutoff date and today is >= 2 days the
  # fetch step is split into 1-day batches. All batches (and all providers
  # within a batch) are executed concurrently via the Async gem.
  class JobsWorkflow
    PROJECT_ROOT    = File.expand_path('../..', __dir__)
    DB_PATH = File.join(PROJECT_ROOT, 'db')
    APPLICATION_CSV = ENV.fetch('APPLICATION_CSV_PATH', File.join(DB_PATH, 'application_mails.csv'))
    INTERVIEWS_CSV  = ENV.fetch('INTERVIEWS_CSV_PATH', File.join(DB_PATH, 'interviews.csv'))
    APPLICATION_CSV_HEADERS = %w[date provider email_id company job_title action].freeze
    INTERVIEWS_CSV_HEADERS  = ['company', 'job title', 'applied at', 'rejected',
                                'first interview', 'second interview', 'third interview',
                                'fourth interview', 'status'].freeze
    LOOKBACK_MONTHS = ENV.fetch('LOOKBACK_MONTHS', '3').to_i
    BATCH_SIZE             = 15
    PROVIDERS              = %w[gmail yahoo].freeze
    # Maximum number of LLM API calls issued concurrently. Keeps us well under
    # provider rate limits when many day-batches × providers are in flight.
    MAX_CONCURRENT_REQUESTS = 2
    # Model pool for rate-limit fallback. When a model is rate-limited,
    # the workflow retries up to RATE_LIMIT_SWITCH_AFTER times then advances
    # to the next model in the pool. If all models are exhausted, re-raises.
    MODELS_POOL             = ['mistral-large-latest', 'gpt-5.1'].freeze
    RATE_LIMIT_SWITCH_AFTER = 2   # retries per model before switching
    RATE_LIMIT_BASE_DELAY   = 5   # seconds; base for exponential backoff within a model

    def initialize(mcp_connection:, model: nil, logger: Pipeline::Logger.new)
      @mcp     = mcp_connection
      @model   = model
      @logger  = logger
      @prompts = Prompts.new(application_csv: APPLICATION_CSV, interviews_csv: INTERVIEWS_CSV)
    end

    def run
      ensure_csv_files_exist
      cutoff_date, existing_ids = step1_init_database
      dates = days_to_process(cutoff_date)

      total_fetched = 0
      total_job     = 0
      total_stored  = 0
      all_summaries = []

      dates.each_with_index do |date, idx|
        @logger.info "=== Day iteration #{idx + 1}/#{dates.size}: #{date} \u2192 #{(Date.parse(date) + 1).iso8601} ==="

        result = run_single_day(date, existing_ids)

        next if result[:emails].empty?

        existing_ids  |= result[:emails].map { |e| e['id'] }
        total_fetched += result[:emails].size

        next if result[:job_list].empty?

        total_job     += result[:job_list].size
        total_stored  += result[:added_rows].size
        all_summaries << result[:summary] if result[:summary]
      end

      return { status: 'no_new_emails' } if total_fetched.zero?
      return { status: 'no_job_emails' }  if total_job.zero?

      { status: 'complete', new_emails: total_fetched,
        job_emails: total_job, rows_added: total_stored,
        reconcile_summaries: all_summaries }
    end

    private

    # Runs the full per-day pipeline (steps 2–5) for a single date.
    # Returns a result hash with :emails, :job_list, :added_rows, :summary.
    # Empty collections indicate the day was skipped at that stage.
    def run_single_day(date, existing_ids)
      before_date = (Date.parse(date) + 1).iso8601

      day_emails = step2_fetch_emails(date, before_date, existing_ids)

      # binding.pry
      if day_emails.empty?
        @logger.info '  No new emails for this period, skipping.'
        return { emails: [], job_list: [], added_rows: [], summary: nil }
      end

      day_job_list = step3_classify(day_emails)

      if day_job_list.empty?
        @logger.info '  No job emails for this period, skipping.'
        return { emails: day_emails, job_list: [], added_rows: [], summary: nil }
      end

      day_added_rows = step4_label_and_store(day_job_list)
      day_summary    = step5_reconcile(day_added_rows)

      { emails: day_emails, job_list: day_job_list, added_rows: day_added_rows, summary: day_summary }
    end

    # ── Workflow steps ─────────────────────────────────────────────────────────

    def ensure_csv_files_exist
      [
        [APPLICATION_CSV, APPLICATION_CSV_HEADERS],
        [INTERVIEWS_CSV,  INTERVIEWS_CSV_HEADERS]
      ].each do |path, headers|
        next if File.exist?(path)

        FileUtils.mkdir_p(File.dirname(path))
        CSV.open(path, 'w') { |csv| csv << headers }
        @logger.info "Created missing CSV: #{path}"
      end
    end

    def step1_init_database
      @logger.info 'Step 1: Initialising CSV database...'
      db_state     = run_agent(Agents::InitDatabaseAgent, @prompts.build_init_message)
      cutoff_date  = extract_date(db_state)
      existing_ids = extract_ids(db_state)
      @logger.debug "  cutoff_date=#{cutoff_date}, existing_ids=#{existing_ids.size}"
      [cutoff_date, existing_ids]
    end

    # Fetches emails for a single date range from all providers concurrently.
    # existing_ids is used to deduplicate against already-seen emails.
    def step2_fetch_emails(after_date, before_date, existing_ids)
      @logger.info 'Step 2: Fetching emails from all providers...'

      all_emails = Sync do
        semaphore = Async::Semaphore.new(MAX_CONCURRENT_REQUESTS)
        tasks = PROVIDERS.map do |provider|
          semaphore.async do
            result = run_agent(Agents::EmailFetchAgent,
                               @prompts.build_fetch_message(provider, after_date, before_date))
            parse_json_array(result).map { |e| e.merge('provider' => provider) }
          end
        end
        tasks.flat_map(&:wait)
      end

      @logger.debug "  fetched #{all_emails.size} total emails"
      new_emails = all_emails.reject { |e| existing_ids.include?(e['id']) }
      @logger.debug "  #{new_emails.size} new emails after deduplication"
      new_emails
    end

    def step3_classify(new_emails)
      @logger.info 'Step 3: Classifying emails...'
      job_emails_json = run_agent(Agents::ClassifyAndFilterAgent, new_emails.to_json)
      job_list        = parse_json_array(job_emails_json)
      @logger.debug "  #{job_list.size} job-related emails found"
      job_list
    end

    def step4_label_and_store(job_list)
      @logger.info 'Step 4: Labelling and storing job emails...'

      added_rows = Sync do
        semaphore = Async::Semaphore.new(MAX_CONCURRENT_REQUESTS)
        tasks = job_list.each_slice(BATCH_SIZE).map do |batch|
          semaphore.async do
            result = run_agent(Agents::LabelAndStoreAgent, @prompts.build_label_store_message(batch))
            parse_json_array(result)
          end
        end
        tasks.flat_map(&:wait)
      end

      @logger.debug "  #{added_rows.size} rows added to CSV"
      added_rows
    end

    def step5_reconcile(added_rows)
      @logger.info 'Step 5: Reconciling interviews.csv...'
      summary = run_agent(Agents::ReconcileInterviewsAgent, @prompts.build_reconcile_message(added_rows))
      @logger.info '  reconciliation complete'
      summary
    end

    # ── Day helpers ───────────────────────────────────────────────────────────

    # Returns an array of ISO-8601 date strings to process, one per day from
    # cutoff_date up to (but not including) today.
    # When the gap is < 2 days a single-element array is returned so at least
    # the cutoff day is always checked.
    def days_to_process(cutoff_date)
      start_date = Date.parse(cutoff_date)
      today      = Date.today
      diff       = (today - start_date).to_i

      return [cutoff_date] if diff < 2

      (0...diff).map { |i| (start_date + i).iso8601 }
    end

    # ── Agent runner ──────────────────────────────────────────────────────────

    # Creates a fresh agent, injects only the MCP tools declared in the agent's
    # TOOLS constant, and returns the response. On RateLimitError the workflow
    # retries up to RATE_LIMIT_SWITCH_AFTER times with exponential backoff, then
    # advances to the next model in MODELS_POOL. Re-raises when all models are
    # exhausted.
    def run_agent(agent_class, message)
      models  = effective_models_pool
      m_idx   = 0
      retries = 0

      begin
        agent = agent_class.new
        agent.with_model(models[m_idx])
        agent.with_tools(*tools_for(agent_class))
        agent.ask(message).content
      rescue RubyLLM::RateLimitError => e
        retries += 1

        if retries > RATE_LIMIT_SWITCH_AFTER
          raise e if m_idx >= models.size - 1

          m_idx  += 1
          retries = 0
          @logger.warn "  Rate limit on #{models[m_idx - 1]}, switching to #{models[m_idx]}..."
        else
          delay = RATE_LIMIT_BASE_DELAY * (2**(retries - 1))
          @logger.warn "  Rate limit hit (attempt #{retries}/#{RATE_LIMIT_SWITCH_AFTER}), " \
                       "retrying with #{models[m_idx]} in #{delay}s..."
          sleep delay
        end

        retry
      end
    end

    # Returns the ordered list of models this workflow may use.
    # When a model was explicitly configured via +model:+, it is placed first;
    # remaining pool entries follow (duplicates removed).
    def effective_models_pool
      return MODELS_POOL unless @model

      ([@model] + MODELS_POOL.reject { |m| m == @model }).freeze
    end

    # Filters the full MCP tool list down to the names declared by the agent.
    def tools_for(agent_class)
      required = agent_class::TOOLS
      @mcp.tools.select { |t| required.include?(t.name) }
    end

    # ── Parsing helpers ────────────────────────────────────────────────────────

    def extract_date(agent_response)
      data = safe_parse_json(agent_response)
      date = data.is_a?(Hash) ? data['latest_date'] : nil
      (date.nil? || date == 'no_date') ? default_beginning_date : date
    rescue StandardError
      default_beginning_date
    end

    def extract_ids(agent_response)
      data = safe_parse_json(agent_response)
      ids  = data.is_a?(Hash) ? data['existing_ids'] : []
      Array(ids)
    rescue StandardError
      []
    end

    def parse_json_array(text)
      return [] if text.nil? || text.strip.empty?

      # Extract a JSON array from the response (may be wrapped in markdown fences)
      json_str = text[/\[.*\]/m] || text
      result   = JSON.parse(json_str)
      return [] unless result.is_a?(Array)

      # Guard against LLMs returning array-of-arrays instead of array-of-objects
      result.select { |e| e.is_a?(Hash) }
    rescue JSON::ParserError
      []
    end

    def safe_parse_json(text)
      return {} if text.nil? || text.strip.empty?

      json_str = text[/\{.*\}/m] || text
      JSON.parse(json_str)
    rescue JSON::ParserError
      {}
    end

    def default_beginning_date
      Date.today.prev_day.iso8601
      # (Date.today << LOOKBACK_MONTHS).iso8601
    end
  end
end
