require_relative '../../spec_helper'
require_relative '../../../lib/services/gmail_service'
require_relative '../../../lib/adapters/gmail_adapter'

RSpec.describe Adapters::GmailAdapter do
  let(:gmail_service) { instance_double(GmailService) }
  subject(:adapter)   { described_class.new(gmail_service) }

  let(:sample_emails) do
    [{ id: 'msg_1', thread_id: 'thread_1', subject: 'Hello', from: 'a@b.com',
       to: 'c@d.com', date: 'Mon, 20 Feb 2026 10:00:00 +0000',
       snippet: 'Hello', body: 'Hello body', labels: ['INBOX'] }]
  end

  describe '#list_messages' do
    it 'delegates to gmail_service#list_messages with mapped args' do
      expect(gmail_service).to receive(:list_messages).with(
        max_results: 5, query: 'is:unread', after_date: nil, before_date: nil,
        offset: 0, label_ids: ['INBOX']
      ).and_return(sample_emails)

      result = adapter.list_messages(max_results: 5, query: 'is:unread', label: 'INBOX')
      expect(result).to eq(sample_emails)
    end

    it 'passes nil label_ids when no label given' do
      expect(gmail_service).to receive(:list_messages).with(hash_including(label_ids: nil)).and_return([])
      adapter.list_messages
    end

    it 'ignores Yahoo-specific kwargs (mailbox, flagged)' do
      expect(gmail_service).to receive(:list_messages).with(hash_including(label_ids: nil)).and_return([])
      adapter.list_messages(mailbox: 'Sent', flagged: true)
    end
  end

  describe '#get_message' do
    it 'delegates to gmail_service#get_message with a string id' do
      expect(gmail_service).to receive(:get_message).with('msg_123').and_return(sample_emails.first)
      result = adapter.get_message('msg_123')
      expect(result).to eq(sample_emails.first)
    end

    it 'coerces integer id to string' do
      expect(gmail_service).to receive(:get_message).with('42').and_return(sample_emails.first)
      adapter.get_message(42)
    end
  end

  describe '#search_messages' do
    it 'delegates to gmail_service#search_messages' do
      expect(gmail_service).to receive(:search_messages).with('query', max_results: 10).and_return(sample_emails)
      result = adapter.search_messages('query')
      expect(result).to eq(sample_emails)
    end
  end

  describe '#get_labels' do
    let(:labels) { [{ id: 'INBOX', name: 'INBOX', type: 'system' }] }

    it 'delegates to gmail_service#get_labels' do
      expect(gmail_service).to receive(:get_labels).and_return(labels)
      expect(adapter.get_labels).to eq(labels)
    end
  end

  describe '#get_unread_count' do
    it 'delegates to gmail_service#get_unread_count' do
      expect(gmail_service).to receive(:get_unread_count).and_return(7)
      expect(adapter.get_unread_count).to eq(7)
    end
  end

  describe '#modify_labels' do
    it 'delegates to gmail_service#modify_labels with add and remove arrays' do
      expect(gmail_service).to receive(:modify_labels).with(
        'msg_1', add_label_ids: ['STARRED'], remove_label_ids: []
      ).and_return({ id: 'msg_1', labels: ['INBOX', 'STARRED'] })

      result = adapter.modify_labels('msg_1', add: ['STARRED'])
      expect(result).to include(:id)
    end
  end
end
