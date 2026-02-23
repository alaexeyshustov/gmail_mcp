require_relative '../../spec_helper'
require_relative '../../../lib/gmail_service'
require_relative '../../../lib/tools/get_labels'

RSpec.describe Tools::GetLabels do
  let(:gmail) { instance_double(GmailService) }
  let(:sample_labels) do
    [
      { id: 'INBOX', name: 'INBOX', type: 'system' },
      { id: 'SENT', name: 'SENT', type: 'system' },
      { id: 'Label_1', name: 'Work', type: 'user' }
    ]
  end

  before { described_class.gmail_service = gmail }

  describe '#call' do
    it 'calls get_labels on the Gmail service' do
      expect(gmail).to receive(:get_labels).and_return(sample_labels)
      tool = described_class.new
      result = tool.call
      expect(result).to eq(sample_labels)
    end

    it 'returns an array of label hashes with id, name, and type' do
      allow(gmail).to receive(:get_labels).and_return(sample_labels)
      tool = described_class.new
      result = tool.call
      expect(result.first).to include(:id, :name, :type)
    end

    context 'when there are no labels' do
      it 'returns an empty array' do
        allow(gmail).to receive(:get_labels).and_return([])
        tool = described_class.new
        expect(tool.call).to eq([])
      end
    end

    context 'when Gmail API raises an error' do
      it 'propagates the error' do
        allow(gmail).to receive(:get_labels).and_raise(Google::Apis::Error.new('API error'))
        tool = described_class.new
        expect { tool.call }.to raise_error(Google::Apis::Error)
      end
    end
  end

  describe '.tool_name' do
    it 'is "get_labels"' do
      expect(described_class.tool_name).to eq('get_labels')
    end
  end
end

