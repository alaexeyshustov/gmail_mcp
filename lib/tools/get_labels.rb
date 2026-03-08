require 'fast_mcp'
require_relative '../provider_registry'

module Tools
  class GetLabels < FastMcp::Tool
    tool_name 'get_labels'
    description 'List all labels (Gmail) or folders (Yahoo), including system and user-created ones.'

    arguments do
      required(:provider).filled(:string)
        .description('Email provider: "gmail" or "yahoo"')
    end

    def call(provider:)
      self.class.registry.fetch(provider).get_labels
    end

    class << self
      attr_accessor :registry
    end
  end
end

