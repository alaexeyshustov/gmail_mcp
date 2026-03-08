require 'fast_mcp'
require_relative '../provider_registry'

module Tools
  class GetUnreadCount < FastMcp::Tool
    tool_name 'get_unread_count'
    description 'Get the number of unread emails in Gmail inbox or a Yahoo Mail folder.'

    arguments do
      required(:provider).filled(:string)
        .description('Email provider: "gmail" or "yahoo"')
      optional(:mailbox).filled(:string)
        .description('Yahoo: mailbox/folder to check. Defaults to INBOX.')
    end

    def call(provider:, mailbox: 'INBOX')
      self.class.registry.fetch(provider).get_unread_count(mailbox: mailbox)
    end

    class << self
      attr_accessor :registry
    end
  end
end

