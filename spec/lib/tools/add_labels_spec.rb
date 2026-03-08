require_relative '../../spec_helper'
require_relative '../../../lib/provider_registry'
require_relative '../../../lib/tools/add_labels'

RSpec.describe Tools::AddLabels do
  let(:gmail_adapter) { double('GmailAdapter') }
  let(:yahoo_adapter) { double('YahooAdapter') }
  let(:registry) do
    r = ProviderRegistry.new
    r.register('gmail', gmail_adapter)
    r.register('yahoo', yahoo_adapter)
    r
  end

  before { described_class.registry = registry }

  describe '#call' do
    context 'with provider: "gmail"' do
      it 'calls modify_labels on the gmail adapter with add array' do
        expected = { id: 'msg_123', labels: ['INBOX', 'STARRED'] }
        expect(gmail_adapter).to receive(:modify_labels)
          .with('msg_123', add: ['STARRED'], mailbox: 'INBOX')
          .and_return(expected)
        result = described_class.new.call(provider: 'gmail', message_id: 'msg_123', label_ids: ['STARRED'])
        expect(result).to eq(expected)
      end

      it 'passes multiple label_ids' do
        expect(gmail_adapter).to receive(:modify_labels)
          .with('msg_123', add: ['STARRED', 'Label_42'], mailbox: 'INBOX')
          .and_return({})
        described_class.new.call(provider: 'gmail', message_id: 'msg_123', label_ids: ['STARRED', 'Label_42'])
      end
    end

    context 'with provider: "yahoo"' do
      it 'calls modify_labels on the yahoo adapter with IMAP flags' do
        expected = { uid: 101, action: 'add', tags: ['\\Flagged'], mailbox: 'INBOX' }
        expect(yahoo_adapter).to receive(:modify_labels)
          .with('101', add: ['\\Flagged'], mailbox: 'INBOX')
          .and_return(expected)
        result = described_class.new.call(provider: 'yahoo', message_id: '101', label_ids: ['\\Flagged'])
        expect(result).to eq(expected)
      end
    end

    context 'with an unknown provider' do
      it 'raises ProviderRegistry::UnknownProviderError' do
        expect { described_class.new.call(provider: 'invalid', message_id: 'id', label_ids: ['X']) }
          .to raise_error(ProviderRegistry::UnknownProviderError)
      end
    end
  end

  describe '.tool_name' do
    it 'is "add_labels"' do
      expect(described_class.tool_name).to eq('add_labels')
    end
  end
end
