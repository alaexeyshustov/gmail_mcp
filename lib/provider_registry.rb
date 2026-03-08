class ProviderRegistry
  class UnknownProviderError < StandardError; end

  def initialize
    @adapters = {}
  end

  # Register a provider adapter.
  # @param name [String, Symbol] Provider name (e.g. "gmail", "yahoo")
  # @param adapter [Adapters::BaseAdapter] Adapter instance
  def register(name, adapter)
    @adapters[name.to_s] = adapter
  end

  # Fetch a registered adapter by name.
  # @raise [UnknownProviderError] when the provider is not registered
  def fetch(name)
    @adapters.fetch(name.to_s) do
      raise UnknownProviderError,
            "Unknown provider '#{name}'. Available: #{@adapters.keys.join(', ')}"
    end
  end

  # List all registered provider names.
  # @return [Array<String>]
  def providers
    @adapters.keys
  end
end
