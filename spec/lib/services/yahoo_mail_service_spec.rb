require_relative '../../spec_helper'

RSpec.describe YahooMailService do
  let(:imap) { instance_double(Net::IMAP) }

  subject(:service) do
    allow(Net::IMAP).to receive(:new).with('imap.mail.yahoo.com', port: 993, ssl: true).and_return(imap)
    allow(imap).to receive(:login).with('user@yahoo.com', 'secret')
    allow(imap).to receive(:select)

    described_class.new(
      host:     'imap.mail.yahoo.com',
      port:     993,
      username: 'user@yahoo.com',
      password: 'secret'
    )
  end

  # ---------------------------------------------------------------------------
  # #initialize
  # ---------------------------------------------------------------------------
  describe '#initialize' do
    it 'connects to the IMAP server with SSL' do
      expect(Net::IMAP).to receive(:new).with('imap.mail.yahoo.com', port: 993, ssl: true).and_return(imap)
      allow(imap).to receive(:login)
      allow(imap).to receive(:select)
      described_class.new(host: 'imap.mail.yahoo.com', port: 993, username: 'user@yahoo.com', password: 'secret')
    end

    it 'authenticates with LOGIN' do
      expect(Net::IMAP).to receive(:new).and_return(imap)
      expect(imap).to receive(:login).with('user@yahoo.com', 'secret')
      allow(imap).to receive(:select)
      described_class.new(host: 'imap.mail.yahoo.com', port: 993, username: 'user@yahoo.com', password: 'secret')
    end
  end

  # ---------------------------------------------------------------------------
  # #get_unread_count
  # ---------------------------------------------------------------------------
  describe '#get_unread_count' do
    it 'returns the UNSEEN count from IMAP STATUS' do
      allow(imap).to receive(:status).with('INBOX', ['UNSEEN']).and_return({ 'UNSEEN' => 7 })
      expect(service.get_unread_count).to eq(7)
    end

    it 'defaults to INBOX mailbox' do
      expect(imap).to receive(:status).with('INBOX', ['UNSEEN']).and_return({ 'UNSEEN' => 0 })
      service.get_unread_count
    end

    it 'accepts a custom mailbox' do
      expect(imap).to receive(:status).with('Sent', ['UNSEEN']).and_return({ 'UNSEEN' => 3 })
      service.get_unread_count(mailbox: 'Sent')
    end

    it 'returns 0 when UNSEEN is nil' do
      allow(imap).to receive(:status).and_return({ 'UNSEEN' => nil })
      expect(service.get_unread_count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # #get_folders
  # ---------------------------------------------------------------------------
  describe '#get_folders' do
    it 'returns an array of folder hashes' do
      allow(imap).to receive(:list).with('', '*').and_return(sample_folders)
      result = service.get_folders
      expect(result).to be_an(Array)
      expect(result.size).to eq(5)
    end

    it 'maps each mailbox to a hash with name, delimiter, and attributes' do
      allow(imap).to receive(:list).with('', '*').and_return(
        [mailbox_list_double(name: 'INBOX', delim: '/', attr: [])]
      )
      result = service.get_folders
      expect(result.first).to include(name: 'INBOX', delimiter: '/', attributes: [])
    end

    it 'returns an empty array when no folders are found' do
      allow(imap).to receive(:list).with('', '*').and_return(nil)
      expect(service.get_folders).to eq([])
    end
  end

  # ---------------------------------------------------------------------------
  # #get_message
  # ---------------------------------------------------------------------------
  describe '#get_message' do
    let(:raw) { plain_text_raw_email(subject: 'Hello World', body: 'Test body content.') }
    let(:fetch_data) { [fetch_data_double(uid: 42, raw_email: raw)] }

    before do
      allow(imap).to receive(:select)
      allow(imap).to receive(:uid_fetch).with(42, %w[RFC822 FLAGS UID]).and_return(fetch_data)
    end

    it 'returns a hash with all expected keys' do
      result = service.get_message(42)
      expect(result.keys).to contain_exactly(:id, :subject, :from, :to, :date, :snippet, :body, :folders)
    end

    it 'sets the id to the UID' do
      expect(service.get_message(42)[:id]).to eq(42)
    end

    it 'extracts the subject' do
      expect(service.get_message(42)[:subject]).to eq('Hello World')
    end

    it 'extracts the from address' do
      expect(service.get_message(42)[:from]).to include('sender@example.com')
    end

    it 'extracts the to address' do
      expect(service.get_message(42)[:to]).to include('recipient@example.com')
    end

    it 'includes the body text' do
      expect(service.get_message(42)[:body]).to include('Test body content.')
    end

    it 'includes a snippet (first 200 chars of body)' do
      result = service.get_message(42)
      expect(result[:snippet].length).to be <= 200
    end

    it 'sets folders to [mailbox]' do
      expect(service.get_message(42, mailbox: 'INBOX')[:folders]).to eq(['INBOX'])
    end

    context 'when subject is missing' do
      let(:raw) { plain_text_raw_email(subject: '') }

      it 'falls back to (No Subject)' do
        result = service.get_message(42)
        expect(result[:subject]).to eq('(No Subject)')
      end
    end

    context 'when fetch returns nil' do
      before do
        allow(imap).to receive(:uid_fetch).and_return(nil)
      end

      it 'returns nil' do
        expect(service.get_message(99)).to be_nil
      end
    end

    context 'with a multipart message' do
      let(:raw) { multipart_raw_email(plain_body: 'Plain text content.', html_body: '<p>HTML content.</p>') }

      it 'prefers the text/plain part' do
        result = service.get_message(42)
        expect(result[:body]).to include('Plain text content.')
        expect(result[:body]).not_to include('<p>')
      end
    end

    context 'with an HTML-only message' do
      let(:raw) { html_only_raw_email(body: '<p>Hello <b>World</b></p>') }

      it 'strips HTML tags from the body' do
        result = service.get_message(42)
        expect(result[:body]).to include('Hello')
        expect(result[:body]).not_to include('<p>')
        expect(result[:body]).not_to include('<b>')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #list_messages
  # ---------------------------------------------------------------------------
  describe '#list_messages' do
    let(:raw1) { plain_text_raw_email(subject: 'First Email') }
    let(:raw2) { plain_text_raw_email(subject: 'Second Email') }
    let(:fetch1) { [fetch_data_double(uid: 101, raw_email: raw1)] }
    let(:fetch2) { [fetch_data_double(uid: 102, raw_email: raw2)] }

    before do
      allow(imap).to receive(:select)
      allow(imap).to receive(:uid_search).and_return([101, 102])
      allow(imap).to receive(:uid_fetch).with(102, anything).and_return(fetch2)
      allow(imap).to receive(:uid_fetch).with(101, anything).and_return(fetch1)
    end

    it 'returns an array of message hashes' do
      results = service.list_messages
      expect(results).to be_an(Array)
      expect(results.size).to eq(2)
    end

    it 'returns messages in reverse UID order (most recent first)' do
      results = service.list_messages
      expect(results.first[:id]).to eq(102)
      expect(results.last[:id]).to eq(101)
    end

    it 'respects max_results' do
      allow(imap).to receive(:uid_search).and_return([100, 101, 102, 103])
      allow(imap).to receive(:uid_fetch).with(anything, anything).and_return(fetch1)
      results = service.list_messages(max_results: 2)
      expect(results.size).to eq(2)
    end

    it 'uses default max_results of 10' do
      uids = (1..15).to_a
      allow(imap).to receive(:uid_search).and_return(uids)
      uids.sort.reverse.first(10).each do |uid|
        allow(imap).to receive(:uid_fetch).with(uid, anything).and_return(fetch1)
      end
      results = service.list_messages
      expect(results.size).to eq(10)
    end

    it 'applies offset for pagination' do
      allow(imap).to receive(:uid_search).and_return([100, 101, 102])
      allow(imap).to receive(:uid_fetch).with(101, anything).and_return(fetch1)
      results = service.list_messages(max_results: 1, offset: 1)
      expect(results.first[:id]).to eq(101)
    end

    it 'passes SINCE criterion for after_date' do
      expect(imap).to receive(:uid_search).with(array_including('SINCE')).and_return([])
      service.list_messages(after_date: Date.new(2024, 1, 1))
    end

    it 'passes BEFORE criterion for before_date' do
      expect(imap).to receive(:uid_search).with(array_including('BEFORE')).and_return([])
      service.list_messages(before_date: Date.new(2024, 12, 31))
    end

    it 'passes FLAGGED criterion when flagged is true' do
      expect(imap).to receive(:uid_search).with(array_including('FLAGGED')).and_return([])
      service.list_messages(flagged: true)
    end

    it 'passes UNFLAGGED criterion when flagged is false' do
      expect(imap).to receive(:uid_search).with(array_including('UNFLAGGED')).and_return([])
      service.list_messages(flagged: false)
    end

    it 'does not pass flagged criteria when flagged is nil' do
      expect(imap).to receive(:uid_search) do |criteria|
        expect(criteria).not_to include('FLAGGED')
        expect(criteria).not_to include('UNFLAGGED')
        []
      end
      service.list_messages(flagged: nil)
    end

    context 'when no messages match' do
      it 'returns an empty array' do
        allow(imap).to receive(:uid_search).and_return([])
        expect(service.list_messages).to eq([])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #search_messages
  # ---------------------------------------------------------------------------
  describe '#search_messages' do
    it 'delegates to list_messages with the given query' do
      expect(service).to receive(:list_messages).with(
        hash_including(query: 'subject:invoice', max_results: 10, mailbox: 'INBOX')
      )
      service.search_messages('subject:invoice')
    end

    it 'accepts custom max_results' do
      expect(service).to receive(:list_messages).with(hash_including(max_results: 20))
      service.search_messages('from:boss@example.com', max_results: 20)
    end

    it 'passes along the mailbox argument' do
      expect(service).to receive(:list_messages).with(hash_including(mailbox: 'Sent'))
      service.search_messages('any', mailbox: 'Sent')
    end
  end

  # ---------------------------------------------------------------------------
  # Query translation (parse_query_criteria)
  # ---------------------------------------------------------------------------
  describe 'IMAP query translation' do
    before do
      allow(imap).to receive(:select)
      allow(imap).to receive(:uid_fetch).and_return(nil)
    end

    {
      'from:alice@example.com' => ['FROM', 'alice@example.com'],
      'to:bob@example.com'     => ['TO',   'bob@example.com'],
      'subject:invoice'        => ['SUBJECT', 'invoice'],
      'is:unread'              => ['UNSEEN'],
      'is:read'                => ['SEEN'],
      'is:flagged'             => ['FLAGGED']
    }.each do |query, expected_criteria|
      it "translates '#{query}' to IMAP criteria #{expected_criteria.inspect}" do
        expect(imap).to receive(:uid_search) do |criteria|
          expected_criteria.each { |token| expect(criteria).to include(token) }
          []
        end
        service.list_messages(query: query)
      end
    end

    it "translates 'after:2024-01-01' to SINCE criterion" do
      expect(imap).to receive(:uid_search) do |criteria|
        expect(criteria).to include('SINCE')
        expect(criteria).to include('01-Jan-2024')
        []
      end
      service.list_messages(query: 'after:2024-01-01')
    end

    it "translates 'before:2024-12-31' to BEFORE criterion" do
      expect(imap).to receive(:uid_search) do |criteria|
        expect(criteria).to include('BEFORE')
        expect(criteria).to include('31-Dec-2024')
        []
      end
      service.list_messages(query: 'before:2024-12-31')
    end

    it 'translates bare words to TEXT search' do
      expect(imap).to receive(:uid_search) do |criteria|
        expect(criteria).to include('TEXT')
        expect(criteria).to include('invoice')
        []
      end
      service.list_messages(query: 'invoice')
    end
  end

  # ---------------------------------------------------------------------------
  # #tag_email
  # ---------------------------------------------------------------------------
  describe '#tag_email' do
    before do
      allow(imap).to receive(:select)
    end

    it 'converts system flags to symbols and adds them with +FLAGS' do
      expect(imap).to receive(:uid_store).with(42, '+FLAGS', [:Flagged])
      result = service.tag_email(42, tags: ['\Flagged'])
      expect(result).to eq({ uid: 42, action: 'add', tags: ['\Flagged'], mailbox: 'INBOX' })
    end

    it 'keeps custom keywords as strings' do
      expect(imap).to receive(:uid_store).with(42, '+FLAGS', ['my-custom-tag'])
      service.tag_email(42, tags: ['my-custom-tag'])
    end

    it 'handles mixed system flags and custom keywords' do
      expect(imap).to receive(:uid_store).with(42, '+FLAGS', [:Flagged, :Seen, 'custom-tag'])
      service.tag_email(42, tags: ['\Flagged', '\Seen', 'custom-tag'])
    end

    it 'uses -FLAGS action when removing tags' do
      expect(imap).to receive(:uid_store).with(42, '-FLAGS', [:Flagged])
      service.tag_email(42, tags: ['\Flagged'], action: 'remove')
    end

    it 'selects the specified mailbox before tagging' do
      expect(imap).to receive(:select).with('Sent')
      expect(imap).to receive(:uid_store).with(42, '+FLAGS', [:Seen])
      service.tag_email(42, tags: ['\Seen'], mailbox: 'Sent')
    end

    it 'handles multiple system flags correctly' do
      expect(imap).to receive(:uid_store).with(100, '+FLAGS', [:Flagged, :Seen, :Answered])
      service.tag_email(100, tags: ['\Flagged', '\Seen', '\Answered'])
    end
  end

  # ---------------------------------------------------------------------------
  # #disconnect
  # ---------------------------------------------------------------------------
  describe '#disconnect' do
    it 'calls logout and disconnect on the IMAP connection' do
      expect(imap).to receive(:logout)
      expect(imap).to receive(:disconnect)
      service.disconnect
    end

    it 'does not raise even if IMAP raises during disconnect' do
      allow(imap).to receive(:logout).and_raise(StandardError, 'already disconnected')
      allow(imap).to receive(:disconnect)
      expect { service.disconnect }.not_to raise_error
    end
  end
end

