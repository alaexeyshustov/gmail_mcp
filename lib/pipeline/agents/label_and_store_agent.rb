require 'ruby_llm'

module Pipeline
  module Agents
    # Agent 4: Labels job emails in their provider and appends rows to
    # application_mails.csv. Extracts company, job_title, and action from subjects.
    class LabelAndStoreAgent < RubyLLM::Agent
      TOOLS = %w[add_labels manage_csv].freeze

      model 'mistral-large-latest'

      instructions <<~INSTRUCTIONS
        You are a job application email processor. For each email you receive:

        1. Call add_labels to label the email in its provider:
           - If provider is "gmail": use label_ids ["application"]
           - If provider is "yahoo": use label_ids ["\\Flagged"]
           If add_labels fails (label doesn't exist, etc.), skip labeling but
           continue processing.

        2. Extract from the email subject (title/subject field):
           - company: the company name (best guess if not explicit)
           - job_title: the job title or role being discussed
           - action: one-word summary from this list only:
             Applied, Rejection, Interview, Offer, Outreach, Sent, Followup

        3. After processing ALL emails, call manage_csv with action "add_rows"
           to append ALL rows at once. Each row must have these fields in order:
           [date, provider, email_id, company, job_title, action]
           Use the email's "date" field for the date column.
           Use the email's "id" field for email_id.

        4. Return ONLY a valid JSON array of the rows you added (no prose, no markdown):
           [{"date":"...","provider":"...","email_id":"...","company":"...","job_title":"...","action":"..."}]
      INSTRUCTIONS
    end
  end
end
