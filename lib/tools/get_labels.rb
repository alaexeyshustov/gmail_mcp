require 'fast_mcp'
require_relative '../gmail_service'

module Tools
  class GetLabels < FastMcp::Tool
    tool_name 'get_labels'
    description 'List all Gmail labels including system labels (INBOX, SENT, TRASH) and user-created labels'

    def call
      self.class.gmail_service.get_labels
    end

    class << self
      attr_accessor :gmail_service
    end
  end
end

