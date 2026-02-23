require 'fast_mcp'
require_relative '../gmail_service'

module Tools
  class ListEmails < FastMcp::Tool
    tool_name 'list_emails'
    description 'List recent emails from Gmail inbox'

    arguments do
      optional(:max_results).filled(:integer).description('Number of emails to return (1-100). Defaults to 10.')
      optional(:query).filled(:string).description("Gmail search query (e.g. 'is:unread', 'from:john@example.com')")
    end

    def call(max_results: 10, query: nil)
      self.class.gmail_service.list_messages(max_results: max_results, query: query)
    end

    class << self
      attr_accessor :gmail_service
    end
  end
end

