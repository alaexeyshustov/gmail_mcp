require_relative '../../spec_helper'
require_relative '../../../lib/gmail_service'
require_relative '../../../lib/tools/get_unread_count'

RSpec.describe Tools::GetUnreadCount do
  let(:gmail) { instance_double(GmailService) }

  before { described_class.gmail_service = gmail }

  describe '#call' do
    it 'calls get_unread_count on the Gmail service' do
      expect(gmail).to receive(:get_unread_count).and_return(42)
      tool = described_class.new
      result = tool.call
      expect(result).to eq(42)
    end

    context 'when there are no unread emails' do
      it 'returns 0' do
        allow(gmail).to receive(:get_unread_count).and_return(0)
        tool = described_class.new
        expect(tool.call).to eq(0)
      end
    end

    context 'when Gmail API raises an error' do
      it 'propagates the error' do
        allow(gmail).to receive(:get_unread_count).and_raise(Google::Apis::Error.new('API error'))
        tool = described_class.new
        expect { tool.call }.to raise_error(Google::Apis::Error)
      end
    end
  end

  describe '.tool_name' do
    it 'is "get_unread_count"' do
      expect(described_class.tool_name).to eq('get_unread_count')
    end
  end
end

