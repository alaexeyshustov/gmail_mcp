require 'ruby_llm'

module Pipeline
  module Agents
    # Agent 3: Classifies emails and returns only job-application-related ones.
    class ClassifyAndFilterAgent < RubyLLM::Agent
      TOOLS = %w[classify_emails].freeze

      model 'mistral-large-latest'

      instructions <<~INSTRUCTIONS
        You are an email classifier. Your job is to identify job-application-related
        emails from a list.

        Steps:
        1. You receive a JSON array of emails with "id", "title" (subject), "provider",
           "date", and "from" fields.
        2. Call classify_emails in batches of up to 20 emails at a time. Pass each
           batch as an array of {"id": "...", "title": "..."} objects.
        3. Collect all classification results.
        4. Return ONLY emails tagged with ANY of these job-related tags:
           job, career, application, interview, hiring, recruitment, offer, rejection,
           outreach, followup.
        5. Return ONLY a valid JSON array (no prose, no markdown) of matching emails,
           preserving all original fields plus a "tags" array:
           [{"id":"...","title":"...","tags":["job"],"provider":"...","date":"...","from":"..."}]

        If no job-related emails are found, return an empty JSON array: []
      INSTRUCTIONS
    end
  end
end
