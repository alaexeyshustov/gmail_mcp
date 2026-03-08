require_relative '../../spec_helper'
require_relative '../../../lib/provider_registry'
require_relative '../../../lib/tools/get_labels'

RSpec.describe Tools::GetLabels do
  let(:gmail_adapter) { double('GmailAdapter') }
  let(:yahoo_adapter) { double('YahooAdapter') }
  let(:registry) do
    r = ProviderRegistry.new
    r.register('gmail', gmail_adapter)
    r.register('yahoo', yahoo_adapter)
    r
  end

  let(:sample_labels) do
    [
      { id: 'INBOX', name: 'INBOX', type: 'system' },
      { id: 'SENT',  name: 'SENT',  type: 'system' },
      { id: 'Label_1', name: 'Work', type: 'user' }
    ]
  end

  before { described_class.registry = registry }

  describe '#call' do
    context 'with provider: "gmail"' do
      it 'calls get_labels on the gmail adapter' do
        expect(gmail_adapter).to receive(:get_labels).and_return(sample_labels)
        result = described_class.new.call(provider: 'gmail')
        expect(result).to eq(sample_labels)
      end

      it 'returns hashes with id, name, and type keys' do
        allow(gmail_adapter).to receive(:get_labels).and_return(sample_labels)
        result = described_class.new.call(provider: 'gmail')
        expect(result.first).to include(:id, :name, :type)
      end

      it 'returns an empty array when there are no labels' do
        allow(gmail_adapter).to receive(:get_labels).and_return([])
        expect(described_class.new.call(provider: 'gmail')).to eq([])
      end
    end

    context 'with provider: "yahoo"' do
      it 'calls get_labels on the yahoo adapter (returns folders)' do
        expect(yahoo_adapter).to receive(:get_labels).and_return(sample_labels)
        result = described_class.new.call(provider: 'yahoo')
        expect(result).to eq(sample_labels)
      end
    end

    context 'with an unknown provider' do
      it 'raises ProviderRegistry::UnknownProviderError' do
        expect { described_class.new.call(provider: 'invalid') }
          .to raise_error(ProviderRegistry::UnknownProviderError)
      end
    end
  end

  describe '.tool_name' do
    it 'is "get_labels"' do
      expect(described_class.tool_name).to eq('get_labels')
    end
  end
end

