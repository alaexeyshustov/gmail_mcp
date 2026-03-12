require_relative '../../spec_helper'

RSpec.describe Tools::ListEmails do
  let(:gmail_adapter) { double('GmailAdapter') }
  let(:yahoo_adapter) { double('YahooAdapter') }
  let(:registry) do
    r = ProviderRegistry.new
    r.register('gmail', gmail_adapter)
    r.register('yahoo', yahoo_adapter)
    r
  end

  let(:gmail_email) do
    { id: 'msg_1', thread_id: 'thread_1', subject: 'Hello', from: 'a@b.com',
      to: 'me@gmail.com', date: 'Mon, 20 Feb 2026 10:00:00 +0000',
      snippet: 'snippet', body: 'body', labels: ['INBOX'] }
  end

  let(:yahoo_email) do
    { id: 101, subject: 'Hello', from: 'a@b.com', to: 'me@yahoo.com',
      date: 'Mon, 20 Feb 2026 10:00:00 +0000',
      snippet: 'snippet', body: 'body', folders: ['INBOX'] }
  end

  before { described_class.registry = registry }

  describe '#call' do
    context 'with provider: "gmail"' do
      it 'calls list_messages on the gmail adapter with defaults' do
        expect(gmail_adapter).to receive(:list_messages).with(
          max_results: 10, query: nil, after_date: nil, before_date: nil,
          offset: 0, label: nil, mailbox: 'INBOX', flagged: nil
        ).and_return([gmail_email])
        expect(described_class.new.call(provider: 'gmail')).to eq([gmail_email])
      end

      it 'passes max_results and query' do
        expect(gmail_adapter).to receive(:list_messages)
          .with(hash_including(max_results: 5, query: 'is:unread'))
          .and_return([])
        described_class.new.call(provider: 'gmail', max_results: 5, query: 'is:unread')
      end

      it 'passes label' do
        expect(gmail_adapter).to receive(:list_messages)
          .with(hash_including(label: 'INBOX'))
          .and_return([gmail_email])
        described_class.new.call(provider: 'gmail', label: 'INBOX')
      end

      it 'parses after_date and before_date strings to Date objects' do
        expect(gmail_adapter).to receive(:list_messages).with(
          hash_including(after_date: Date.new(2024, 1, 1), before_date: Date.new(2024, 12, 31))
        ).and_return([])
        described_class.new.call(provider: 'gmail', after_date: '2024-01-01', before_date: '2024-12-31')
      end
    end

    context 'with provider: "yahoo"' do
      it 'calls list_messages on the yahoo adapter with mailbox and flagged' do
        expect(yahoo_adapter).to receive(:list_messages).with(
          max_results: 10, query: nil, after_date: nil, before_date: nil,
          offset: 0, label: nil, mailbox: 'Sent', flagged: true
        ).and_return([yahoo_email])
        described_class.new.call(provider: 'yahoo', mailbox: 'Sent', flagged: true)
      end
    end

    context 'with an unknown provider' do
      it 'raises ProviderRegistry::UnknownProviderError' do
        expect { described_class.new.call(provider: 'outlook') }
          .to raise_error(ProviderRegistry::UnknownProviderError)
      end
    end
  end

  describe '.tool_name' do
    it 'is "list_emails"' do
      expect(described_class.tool_name).to eq('list_emails')
    end
  end
end

