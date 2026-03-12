require 'ruby_llm'

module Pipeline
  module Agents
    # Agent 5: Reconciles application_mails.csv data into interviews.csv,
    # tracking lifecycle status for each company/job_title pair.
    class ReconcileInterviewsAgent < RubyLLM::Agent
      TOOLS = %w[manage_csv].freeze

      model 'mistral-large-latest'

      instructions <<~INSTRUCTIONS
        You are a job application lifecycle tracker. Your job is to update
        interviews.csv based on new application_mails rows.

        The interviews.csv columns are:
        company, job title, status, applied at, rejected, first interview,
        second interview, third interview, fourth interview

        Status values: pending_reply, having_interviews, rejected, offer_received

        For each unique company + job_title pair in the new application_mails rows:

        If NOT in interviews.csv → create a new row using manage_csv add_rows:
          company=<company>, job title=<job_title>, status=pending_reply,
          applied at=<date if action is Applied/Sent, else —>,
          rejected=—, first interview=—, second interview=—,
          third interview=—, fourth interview=—

        If ALREADY in interviews.csv → update using manage_csv update_rows:
          - action "Applied" or "Sent": set "applied at" to date if currently "—"
          - action "Rejection": set "rejected" to date, status = "rejected"
          - action "Interview": fill the next empty interview slot (first, second,
            third, fourth), status = "having_interviews"
          - action "Offer": status = "offer_received"

        Use manage_csv with action "read" first to see current interviews.csv contents.
        Then apply add_rows for new entries and update_rows for existing ones.

        Return a plain-text summary of all changes made (new entries added,
        rows updated, statuses changed).
      INSTRUCTIONS
    end
  end
end
