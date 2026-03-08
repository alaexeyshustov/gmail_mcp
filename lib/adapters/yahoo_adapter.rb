require_relative './base_adapter'
require_relative '../services/yahoo_mail_service'

module Adapters
  # Adapts YahooMailService to the unified BaseAdapter interface.
  # Yahoo-specific arguments (mailbox:, flagged:) are accepted as optional kwargs
  # and passed through to the underlying service.
  class YahooAdapter < BaseAdapter
    def initialize(yahoo_mail_service)
      @service = yahoo_mail_service
    end

    def list_messages(max_results: 10, query: nil, after_date: nil, before_date: nil,
                      offset: 0, mailbox: 'INBOX', flagged: nil, **_ignored)
      @service.list_messages(
        mailbox:      mailbox,
        max_results:  max_results,
        query:        query,
        flagged:      flagged,
        after_date:   after_date,
        before_date:  before_date,
        offset:       offset
      )
    end

    def get_message(message_uid, mailbox: 'INBOX', **_ignored)
      @service.get_message(message_uid.to_i, mailbox: mailbox)
    end

    def search_messages(query, max_results: 10, mailbox: 'INBOX', **_ignored)
      @service.search_messages(query, max_results: max_results, mailbox: mailbox)
    end

    # Returns Yahoo folders mapped to the unified label shape:
    #   [{ id: String, name: String, type: String }]
    def get_labels(**_ignored)
      @service.get_folders.map do |folder|
        {
          id:   folder[:name],
          name: folder[:name],
          type: (folder[:attributes]&.first || 'user').to_s
        }
      end
    end

    def get_unread_count(mailbox: 'INBOX', **_ignored)
      @service.get_unread_count(mailbox: mailbox)
    end

    # Adds IMAP flags to a message. Remove is supported via the remove: keyword.
    def modify_labels(message_uid, add: [], remove: [], mailbox: 'INBOX', **_ignored)
      result = {}
      unless add.empty?
        result = @service.tag_email(message_uid.to_i, tags: add, mailbox: mailbox, action: 'add')
      end
      unless remove.empty?
        result = @service.tag_email(message_uid.to_i, tags: remove, mailbox: mailbox, action: 'remove')
      end
      result
    end
  end
end
