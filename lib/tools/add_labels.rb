require 'fast_mcp'

module Tools
  class AddLabels < FastMcp::Tool
    tool_name 'add_labels'
    description 'Add one or more labels/flags to a specific email. ' \
                'Gmail: use label IDs (e.g. "STARRED"). ' \
                'Yahoo: use IMAP flags (e.g. "\\Flagged", "\\Seen"). ' \
                'Use get_labels to list available labels/folders first.'

    arguments do
      required(:provider).filled(:string)
        .description('Email provider: "gmail" or "yahoo"')
      required(:message_id).filled(:string)
        .description('The message ID (Gmail string ID or Yahoo IMAP UID as string).')
      required(:label_ids).array(:string)
        .description('Array of label IDs or IMAP flags to add (e.g. ["STARRED"] or ["\\\\Flagged"]).')
      optional(:mailbox).filled(:string)
        .description('Yahoo: mailbox/folder containing the message. Defaults to INBOX.')
    end

    def call(provider:, message_id:, label_ids:, mailbox: 'INBOX')
      self.class.registry.fetch(provider).modify_labels(
        message_id,
        add:     label_ids,
        mailbox: mailbox
      )
    end

    class << self
      attr_accessor :registry
    end
  end
end
