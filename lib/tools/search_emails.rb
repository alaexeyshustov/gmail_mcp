require 'fast_mcp'
require_relative '../gmail_service'

module Tools
  class SearchEmails < FastMcp::Tool
    tool_name 'search_emails'
    description 'Search Gmail using a query string and return matching emails'

    arguments do
      required(:query).filled(:string).description(
        "Gmail search query (e.g. 'from:boss@example.com', 'subject:invoice', 'is:unread after:2024/01/01')"
      )
      optional(:max_results).filled(:integer).description('Maximum number of results to return (1-100). Defaults to 10.')
    end

    def call(query:, max_results: 10)
      self.class.gmail_service.search_messages(query, max_results: max_results)
    end

    class << self
      attr_accessor :gmail_service
    end
  end
end

