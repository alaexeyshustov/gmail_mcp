require_relative '../spec_helper'
require_relative '../../lib/provider_registry'

RSpec.describe ProviderRegistry do
  subject(:registry) { described_class.new }

  let(:gmail_adapter)  { double('GmailAdapter') }
  let(:yahoo_adapter)  { double('YahooAdapter') }

  describe '#register and #fetch' do
    it 'registers and retrieves an adapter by name' do
      registry.register('gmail', gmail_adapter)
      expect(registry.fetch('gmail')).to eq(gmail_adapter)
    end

    it 'accepts symbol keys when registering' do
      registry.register(:gmail, gmail_adapter)
      expect(registry.fetch('gmail')).to eq(gmail_adapter)
    end

    it 'accepts symbol keys when fetching' do
      registry.register('yahoo', yahoo_adapter)
      expect(registry.fetch(:yahoo)).to eq(yahoo_adapter)
    end

    it 'supports multiple providers' do
      registry.register('gmail', gmail_adapter)
      registry.register('yahoo', yahoo_adapter)
      expect(registry.fetch('gmail')).to eq(gmail_adapter)
      expect(registry.fetch('yahoo')).to eq(yahoo_adapter)
    end
  end

  describe '#fetch with unknown provider' do
    it 'raises UnknownProviderError' do
      registry.register('gmail', gmail_adapter)
      expect { registry.fetch('yahoo') }
        .to raise_error(ProviderRegistry::UnknownProviderError, /Unknown provider 'yahoo'/)
    end

    it 'includes available providers in the error message' do
      registry.register('gmail', gmail_adapter)
      expect { registry.fetch('outlook') }
        .to raise_error(ProviderRegistry::UnknownProviderError, /gmail/)
    end
  end

  describe '#providers' do
    it 'returns an empty array when no providers are registered' do
      expect(registry.providers).to eq([])
    end

    it 'returns all registered provider names' do
      registry.register('gmail', gmail_adapter)
      registry.register('yahoo', yahoo_adapter)
      expect(registry.providers).to contain_exactly('gmail', 'yahoo')
    end
  end
end
