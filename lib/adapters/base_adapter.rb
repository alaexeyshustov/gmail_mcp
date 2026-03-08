module Adapters
  # Abstract base class defining the interface all provider adapters must implement.
  # Subclasses override each method to delegate to their underlying service.
  class BaseAdapter
    def list_messages(**opts)
      raise NotImplementedError, "#{self.class}#list_messages is not implemented"
    end

    def get_message(message_id, **opts)
      raise NotImplementedError, "#{self.class}#get_message is not implemented"
    end

    def search_messages(query, **opts)
      raise NotImplementedError, "#{self.class}#search_messages is not implemented"
    end

    # Returns labels (Gmail) or folders (Yahoo) in a unified shape:
    #   [{ id: String, name: String, type: String }]
    def get_labels(**opts)
      raise NotImplementedError, "#{self.class}#get_labels is not implemented"
    end

    def get_unread_count(**opts)
      raise NotImplementedError, "#{self.class}#get_unread_count is not implemented"
    end

    # Adds or removes labels/flags on a message.
    # @param message_id [String, Integer] Provider-specific message identifier
    # @param add  [Array<String>] Labels/flags to add
    # @param remove [Array<String>] Labels/flags to remove
    def modify_labels(message_id, add: [], remove: [], **opts)
      raise NotImplementedError, "#{self.class}#modify_labels is not implemented"
    end
  end
end
