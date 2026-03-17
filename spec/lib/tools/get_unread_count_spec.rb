require_relative '../../spec_helper'

RSpec.describe Tools::GetUnreadCount do
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
      it 'calls get_unread_count on the gmail adapter' do
        expect(gmail_adapter).to receive(:get_unread_count).with(mailbox: 'INBOX').and_return(42)
        expect(described_class.new.call(provider: 'gmail')).to eq(42)
      end

      it 'returns 0 when there are no unread emails' do
        allow(gmail_adapter).to receive(:get_unread_count).and_return(0)
        expect(described_class.new.call(provider: 'gmail')).to eq(0)
      end
    end

    context 'with provider: "yahoo"' do
      it 'calls get_unread_count on the yahoo adapter with mailbox' do
        expect(yahoo_adapter).to receive(:get_unread_count).with(mailbox: 'Sent').and_return(3)
        described_class.new.call(provider: 'yahoo', mailbox: 'Sent')
      end

      it 'defaults to INBOX' do
        expect(yahoo_adapter).to receive(:get_unread_count).with(mailbox: 'INBOX').and_return(7)
        described_class.new.call(provider: 'yahoo')
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
    it 'is "get_unread_count"' do
      expect(described_class.tool_name).to eq('get_unread_count')
    end
  end
end

