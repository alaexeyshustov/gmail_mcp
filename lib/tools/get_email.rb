require 'fast_mcp'
require_relative '../gmail_service'

module Tools
  class GetEmail < FastMcp::Tool
    tool_name 'get_email'
    description 'Get the full content of a specific email by its Gmail message ID'

    arguments do
      required(:message_id).filled(:string).description('The Gmail message ID (e.g. "18d3f1a2b3c4d5e6")')
    end

    def call(message_id:)
      self.class.gmail_service.get_message(message_id)
    end

    class << self
      attr_accessor :gmail_service
    end
  end
end

