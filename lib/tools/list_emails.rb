require 'fast_mcp'

module Tools
  class ListEmails < FastMcp::Tool
    tool_name 'list_emails'
    description 'List recent emails from Gmail or Yahoo Mail inbox.'

    arguments do
      required(:provider).filled(:string)
        .description('Email provider: "gmail" or "yahoo"')
      optional(:max_results).filled(:integer)
        .description('Number of emails to return (1-100). Defaults to 10.')
      optional(:query).filled(:string)
        .description("Search query (e.g. 'is:unread', 'from:john@example.com')")
      optional(:after_date).filled(:string)
        .description('Return emails after this date (YYYY-MM-DD format).')
      optional(:before_date).filled(:string)
        .description('Return emails before this date (YYYY-MM-DD format).')
      optional(:offset).filled(:integer)
        .description('Number of emails to skip (for pagination). Defaults to 0.')
      optional(:label).filled(:string)
        .description('Gmail: filter by label ID or name (e.g. "INBOX", "UNREAD").')
      optional(:mailbox).filled(:string)
        .description('Yahoo: mailbox/folder name (e.g. "INBOX", "Sent"). Defaults to INBOX.')
      optional(:flagged).filled(:bool)
        .description('Yahoo: filter by flagged status. true = only flagged, false = only unflagged.')
    end

    def call(provider:, max_results: 10, query: nil, after_date: nil, before_date: nil,
             offset: 0, label: nil, mailbox: 'INBOX', flagged: nil)
      parsed_after  = after_date  ? Date.parse(after_date)  : nil
      parsed_before = before_date ? Date.parse(before_date) : nil
      self.class.registry.fetch(provider).list_messages(
        max_results:  max_results,
        query:        query,
        after_date:   parsed_after,
        before_date:  parsed_before,
        offset:       offset,
        label:        label,
        mailbox:      mailbox,
        flagged:      flagged
      )
    end

    class << self
      attr_accessor :registry
    end
  end
end

