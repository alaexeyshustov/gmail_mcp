require_relative '../../spec_helper'
require_relative '../../../lib/gmail_service'
require_relative '../../../lib/tools/search_emails'

RSpec.describe Tools::SearchEmails do
  let(:gmail) { instance_double(GmailService) }
  let(:sample_emails) do
    [
      {
        id: 'msg_1',
        thread_id: 'thread_1',
        subject: 'Invoice January',
        from: 'billing@example.com',
        to: 'me@example.com',
        date: 'Mon, 20 Feb 2026 10:00:00 +0000',
        snippet: 'Invoice snippet',
        body: 'Invoice body',
        labels: ['INBOX']
      }
    ]
  end

  before { described_class.gmail_service = gmail }

  describe '#call' do
    context 'with required query and default max_results' do
      it 'calls search_messages with query and default max_results: 10' do
        expect(gmail).to receive(:search_messages).with('subject:invoice', max_results: 10).and_return(sample_emails)
        tool = described_class.new
        result = tool.call(query: 'subject:invoice')
        expect(result).to eq(sample_emails)
      end
    end

    context 'with custom max_results' do
      it 'passes max_results to search_messages' do
        expect(gmail).to receive(:search_messages).with('from:boss@example.com', max_results: 25).and_return([])
        tool = described_class.new
        result = tool.call(query: 'from:boss@example.com', max_results: 25)
        expect(result).to eq([])
      end
    end

    context 'when no results are found' do
      it 'returns an empty array' do
        allow(gmail).to receive(:search_messages).and_return([])
        tool = described_class.new
        expect(tool.call(query: 'nothing_matches')).to eq([])
      end
    end

    context 'when Gmail API raises an error' do
      it 'propagates the error' do
        allow(gmail).to receive(:search_messages).and_raise(Google::Apis::Error.new('API error'))
        tool = described_class.new
        expect { tool.call(query: 'any') }.to raise_error(Google::Apis::Error)
      end
    end
  end

  describe '.tool_name' do
    it 'is "search_emails"' do
      expect(described_class.tool_name).to eq('search_emails')
    end
  end
end

