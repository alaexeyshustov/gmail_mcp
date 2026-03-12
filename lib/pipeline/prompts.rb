module Pipeline
  # Builds the prompt strings passed to each workflow agent.
  # Centralises all natural-language instructions so they can be read,
  # tested, and tuned independently of orchestration logic.
  class Prompts
    def initialize(application_csv:, interviews_csv:)
      @application_csv = application_csv
      @interviews_csv  = interviews_csv
    end

    def build_init_message
      "Read the CSV file at #{@application_csv}. " \
      "Return the latest date and all email_id values as JSON: " \
      '{"latest_date": "YYYY-MM-DD or no_date", "existing_ids": ["id1",...]}'
    end

    def build_fetch_message(provider, after_date, before_date = nil)
      msg = "List all emails from provider \"#{provider}\" with after_date \"#{after_date}\""
      msg += " and before_date \"#{before_date}\"" if before_date
      msg += ". Paginate if needed. Return a JSON array: " \
             '[{"id":"...","subject":"...","date":"...","from":"..."}]'
      msg
    end

    def build_label_store_message(batch)
      "Process these job emails. Label them in their provider and append all rows " \
      "to #{@application_csv}:\n#{batch.to_json}"
    end

    def build_reconcile_message(added_rows)
      "New application_mails rows:\n#{added_rows.to_json}\n\n" \
      "Update the interviews CSV at #{@interviews_csv}. " \
      "Read it first to see existing data, then add/update rows."
    end
  end
end
