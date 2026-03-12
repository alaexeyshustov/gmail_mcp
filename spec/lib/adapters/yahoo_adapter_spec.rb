require_relative '../../spec_helper'

RSpec.describe Adapters::YahooAdapter do
  let(:yahoo_service) { instance_double(YahooMailService) }
  subject(:adapter)   { described_class.new(yahoo_service) }

  let(:sample_emails) do
    [{ id: 101, subject: 'Hello', from: 'a@b.com', to: 'c@yahoo.com',
       date: 'Mon, 20 Feb 2026 10:00:00 +0000',
       snippet: 'Hello snippet', body: 'Hello body', folders: ['INBOX'] }]
  end

  describe '#list_messages' do
    it 'delegates to yahoo_service#list_messages with mapped args' do
      expect(yahoo_service).to receive(:list_messages).with(
        mailbox: 'Sent', max_results: 5, query: 'is:unread', flagged: nil,
        after_date: nil, before_date: nil, offset: 0
      ).and_return(sample_emails)

      result = adapter.list_messages(max_results: 5, query: 'is:unread', mailbox: 'Sent')
      expect(result).to eq(sample_emails)
    end

    it 'defaults mailbox to INBOX' do
      expect(yahoo_service).to receive(:list_messages).with(hash_including(mailbox: 'INBOX')).and_return([])
      adapter.list_messages
    end

    it 'ignores Gmail-specific kwargs (label)' do
      expect(yahoo_service).to receive(:list_messages).with(hash_including(mailbox: 'INBOX')).and_return([])
      adapter.list_messages(label: 'UNREAD')
    end
  end

  describe '#get_message' do
    it 'delegates to yahoo_service#get_message with integer uid and mailbox' do
      expect(yahoo_service).to receive(:get_message).with(101, mailbox: 'INBOX').and_return(sample_emails.first)
      result = adapter.get_message(101)
      expect(result).to eq(sample_emails.first)
    end

    it 'coerces string id to integer' do
      expect(yahoo_service).to receive(:get_message).with(101, mailbox: 'INBOX').and_return(sample_emails.first)
      adapter.get_message('101')
    end

    it 'passes custom mailbox' do
      expect(yahoo_service).to receive(:get_message).with(42, mailbox: 'Sent').and_return(nil)
      adapter.get_message(42, mailbox: 'Sent')
    end
  end

  describe '#search_messages' do
    it 'delegates to yahoo_service#search_messages' do
      expect(yahoo_service).to receive(:search_messages).with('query', max_results: 10, mailbox: 'INBOX').and_return(sample_emails)
      result = adapter.search_messages('query')
      expect(result).to eq(sample_emails)
    end
  end

  describe '#get_labels' do
    it 'returns folders mapped to unified label shape' do
      allow(yahoo_service).to receive(:get_folders).and_return(
        [{ name: 'INBOX', delimiter: '/', attributes: ['\\HasNoChildren'] }]
      )
      result = adapter.get_labels
      expect(result).to eq([{ id: 'INBOX', name: 'INBOX', type: '\\HasNoChildren' }])
    end

    it 'returns empty array when no folders' do
      allow(yahoo_service).to receive(:get_folders).and_return([])
      expect(adapter.get_labels).to eq([])
    end
  end

  describe '#get_unread_count' do
    it 'delegates to yahoo_service#get_unread_count with INBOX default' do
      expect(yahoo_service).to receive(:get_unread_count).with(mailbox: 'INBOX').and_return(3)
      expect(adapter.get_unread_count).to eq(3)
    end

    it 'passes custom mailbox' do
      expect(yahoo_service).to receive(:get_unread_count).with(mailbox: 'Sent').and_return(0)
      adapter.get_unread_count(mailbox: 'Sent')
    end
  end

  describe '#modify_labels' do
    it 'calls tag_email with add action for add labels' do
      expect(yahoo_service).to receive(:tag_email).with(
        101, tags: ['\\Flagged'], mailbox: 'INBOX', action: 'add'
      ).and_return({ uid: 101, action: 'add', tags: ['\\Flagged'], mailbox: 'INBOX' })

      adapter.modify_labels(101, add: ['\\Flagged'])
    end

    it 'calls tag_email with remove action for remove labels' do
      expect(yahoo_service).to receive(:tag_email).with(
        101, tags: ['\\Flagged'], mailbox: 'INBOX', action: 'remove'
      ).and_return({ uid: 101, action: 'remove', tags: ['\\Flagged'], mailbox: 'INBOX' })

      adapter.modify_labels(101, remove: ['\\Flagged'])
    end
  end
end
