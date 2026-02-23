require 'fast_mcp'
require_relative '../gmail_service'

module Tools
  class GetUnreadCount < FastMcp::Tool
    tool_name 'get_unread_count'
    description 'Get the total number of unread emails in the Gmail inbox'

    def call
      self.class.gmail_service.get_unread_count
    end

    class << self
      attr_accessor :gmail_service
    end
  end
end

