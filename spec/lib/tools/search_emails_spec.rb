require_relative '../../spec_helper'
require_relative '../../../lib/provider_registry'
require_relative '../../../lib/tools/search_emails'

RSpec.describe Tools::SearchEmails do
  let(:gmail_adapter) { double('GmailAdapter') }
  let(:yahoo_adapter) { double('YahooAdapter') }
  let(:registry) do
    r = ProviderRegistry.new
    r.register('gmail', gmail_adapter)
    r.register('yahoo', yahoo_adapter)
    r
  end

  let(:sample_emails) { [{ id: 'msg_1', subject: 'Invoice', labels: ['INBOX'] }] }

  before { described_class.registry = registry }

  describe '#call' do
    context 'with provider: "gmail"' do
      it 'calls search_messages on the gmail adapter with defaults' do
        expect(gmail_adapter).to receive(:search_messages)
          .with('subject:invoice', max_results: 10, mailbox: 'INBOX')
          .and_return(sample_emails)
        result = described_class.new.call(provider: 'gmail', query: 'subject:invoice')
        expect(result).to eq(sample_emails)
      end

      it 'passes custom max_results' do
        expect(gmail_adapter).to receive(:search_messages)
          .with('from:boss', max_results: 25, mailbox: 'INBOX')
          .and_return([])
        described_class.new.call(provider: 'gmail', query: 'from:boss', max_results: 25)
      end
    end

    context 'with provider: "yahoo"' do
      it 'calls search_messages on the yahoo adapter with mailbox' do
        expect(yahoo_adapter).to receive(:search_messages)
          .with('is:unread', max_results: 10, mailbox: 'Sent')
          .and_return([])
        described_class.new.call(provider: 'yahoo', query: 'is:unread', mailbox: 'Sent')
      end
    end

    context 'with an unknown provider' do
      it 'raises ProviderRegistry::UnknownProviderError' do
        expect { described_class.new.call(provider: 'invalid', query: 'test') }
          .to raise_error(ProviderRegistry::UnknownProviderError)
      end
    end
  end

  describe '.tool_name' do
    it 'is "search_emails"' do
      expect(described_class.tool_name).to eq('search_emails')
    end
  end
end

