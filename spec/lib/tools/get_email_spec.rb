require_relative '../../spec_helper'
require_relative '../../../lib/gmail_service'
require_relative '../../../lib/tools/get_email'

RSpec.describe Tools::GetEmail do
  let(:gmail) { instance_double(GmailService) }
  let(:sample_email) do
    {
      id: 'msg_123',
      thread_id: 'thread_123',
      subject: 'Test Subject',
      from: 'sender@example.com',
      to: 'me@example.com',
      date: 'Mon, 20 Feb 2026 10:00:00 +0000',
      snippet: 'Test snippet',
      body: 'Test body',
      labels: ['INBOX']
    }
  end

  before { described_class.gmail_service = gmail }

  describe '#call' do
    it 'calls get_message with the given message_id' do
      expect(gmail).to receive(:get_message).with('msg_123').and_return(sample_email)
      tool = described_class.new
      result = tool.call(message_id: 'msg_123')
      expect(result).to eq(sample_email)
    end

    it 'returns the hash with all expected keys' do
      allow(gmail).to receive(:get_message).with('msg_123').and_return(sample_email)
      tool = described_class.new
      result = tool.call(message_id: 'msg_123')
      expect(result.keys).to include(:id, :thread_id, :subject, :from, :to, :date, :snippet, :body, :labels)
    end

    context 'when Gmail API raises an error' do
      it 'propagates the error' do
        allow(gmail).to receive(:get_message).and_raise(Google::Apis::Error.new('Not found'))
        tool = described_class.new
        expect { tool.call(message_id: 'nonexistent') }.to raise_error(Google::Apis::Error)
      end
    end
  end

  describe '.tool_name' do
    it 'is "get_email"' do
      expect(described_class.tool_name).to eq('get_email')
    end
  end
end

