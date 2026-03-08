require 'fast_mcp'
require_relative '../provider_registry'

module Tools
  class GetEmail < FastMcp::Tool
    tool_name 'get_email'
    description 'Get the full content of a specific email by its message ID or IMAP UID.'

    arguments do
      required(:provider).filled(:string)
        .description('Email provider: "gmail" or "yahoo"')
      required(:message_id).filled(:string)
        .description('The message ID (Gmail string ID or Yahoo IMAP UID as string).')
      optional(:mailbox).filled(:string)
        .description('Yahoo: mailbox/folder containing the message. Defaults to INBOX.')
    end

    def call(provider:, message_id:, mailbox: 'INBOX')
      self.class.registry.fetch(provider).get_message(message_id, mailbox: mailbox)
    end

    class << self
      attr_accessor :registry
    end
  end
end

