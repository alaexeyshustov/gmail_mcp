require_relative '../../spec_helper'

RSpec.describe Tools::GetEmail do
  let(:gmail_adapter) { double('GmailAdapter') }
  let(:yahoo_adapter) { double('YahooAdapter') }
  let(:registry) do
    r = ProviderRegistry.new
    r.register('gmail', gmail_adapter)
    r.register('yahoo', yahoo_adapter)
    r
  end

  let(:gmail_email) do
    { id: 'msg_123', thread_id: 'thread_123', subject: 'Test Subject',
      from: 'sender@example.com', to: 'me@gmail.com',
      date: 'Mon, 20 Feb 2026 10:00:00 +0000',
      snippet: 'Test snippet', body: 'Test body', labels: ['INBOX'] }
  end

  let(:yahoo_email) do
    { id: 101, subject: 'Test Subject', from: 'sender@example.com',
      to: 'me@yahoo.com', date: 'Mon, 20 Feb 2026 10:00:00 +0000',
      snippet: 'Test snippet', body: 'Test body', folders: ['INBOX'] }
  end

  before { described_class.registry = registry }

  describe '#call' do
    context 'with provider: "gmail"' do
      it 'calls get_message on the gmail adapter' do
        expect(gmail_adapter).to receive(:get_message).with('msg_123', mailbox: 'INBOX').and_return(gmail_email)
        result = described_class.new.call(provider: 'gmail', message_id: 'msg_123')
        expect(result).to eq(gmail_email)
      end

      it 'passes a custom mailbox' do
        expect(gmail_adapter).to receive(:get_message).with('msg_123', mailbox: 'Sent').and_return(gmail_email)
        described_class.new.call(provider: 'gmail', message_id: 'msg_123', mailbox: 'Sent')
      end
    end

    context 'with provider: "yahoo"' do
      it 'calls get_message on the yahoo adapter with mailbox' do
        expect(yahoo_adapter).to receive(:get_message).with('101', mailbox: 'INBOX').and_return(yahoo_email)
        result = described_class.new.call(provider: 'yahoo', message_id: '101')
        expect(result).to eq(yahoo_email)
      end
    end

    context 'with an unknown provider' do
      it 'raises ProviderRegistry::UnknownProviderError' do
        expect { described_class.new.call(provider: 'outlook', message_id: 'id') }
          .to raise_error(ProviderRegistry::UnknownProviderError)
      end
    end
  end

  describe '.tool_name' do
    it 'is "get_email"' do
      expect(described_class.tool_name).to eq('get_email')
    end
  end
end

