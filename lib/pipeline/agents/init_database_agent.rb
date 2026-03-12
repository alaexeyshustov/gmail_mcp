require 'ruby_llm'

module Pipeline
  module Agents
    # Agent 1: Reads or initialises application_mails.csv and returns the latest
    # date and all known email IDs so the workflow can deduplicate new emails.
    class InitDatabaseAgent < RubyLLM::Agent
      TOOLS = %w[manage_csv].freeze

      model 'mistral-large-latest'

      instructions <<~INSTRUCTIONS
        You are a CSV database manager. Your job is to read an existing CSV file
        and return its state as JSON.

        When you read the CSV:
        - Identify the most recent "date" value in the rows (YYYY-MM-DD format).
        - Collect all "email_id" values.

        Return ONLY a valid JSON object in this exact format (no prose, no markdown):
        {"latest_date": "YYYY-MM-DD or no_date", "existing_ids": ["id1", "id2", ...]}

        If the file has no rows, use "no_date" for latest_date and [] for existing_ids.
        If manage_csv returns an error, use "no_date" and [].
      INSTRUCTIONS
    end
  end
end
