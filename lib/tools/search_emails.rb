require 'fast_mcp'
require_relative '../provider_registry'

module Tools
  class SearchEmails < FastMcp::Tool
    tool_name 'search_emails'
    description 'Search Gmail or Yahoo Mail using a query string and return matching emails.'

    arguments do
      required(:provider).filled(:string)
        .description('Email provider: "gmail" or "yahoo"')
      required(:query).filled(:string)
        .description(
          "Search query (e.g. 'from:boss@example.com', 'subject:invoice', 'is:unread')"
        )
      optional(:max_results).filled(:integer)
        .description('Maximum number of results to return (1-100). Defaults to 10.')
      optional(:mailbox).filled(:string)
        .description('Yahoo: mailbox/folder to search. Defaults to INBOX.')
    end

    def call(provider:, query:, max_results: 10, mailbox: 'INBOX')
      self.class.registry.fetch(provider).search_messages(
        query,
        max_results: max_results,
        mailbox:     mailbox
      )
    end

    class << self
      attr_accessor :registry
    end
  end
end

