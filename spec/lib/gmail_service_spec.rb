# frozen_string_literal: true

require_relative  '../spec_helper'
require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require_relative '../../lib/gmail_service'

RSpec.describe GmailService do
  let(:credentials_path) { '/fake/credentials.json' }
  let(:token_path) { '/fake/token.yaml' }
  let(:mock_credentials) { double('credentials') }
  let(:mock_service) { instance_double(Google::Apis::GmailV1::GmailService) }
  let(:mock_client_options) { double('client_options', application_name: nil, 'application_name=' => nil) }

  subject(:client) do
    allow(Google::Apis::GmailV1::GmailService).to receive(:new).and_return(mock_service)
    allow(mock_service).to receive(:client_options).and_return(mock_client_options)
    allow(mock_service).to receive(:authorization=)

    allow_any_instance_of(described_class).to receive(:authorize).and_return(mock_credentials)

    described_class.new(credentials_path: credentials_path, token_path: token_path)
  end

  describe '#initialize' do
    it 'creates a new Gmail service' do
      expect(client.service).to eq(mock_service)
    end

    it 'sets the authorization on the service' do
      allow(Google::Apis::GmailV1::GmailService).to receive(:new).and_return(mock_service)
      allow(mock_service).to receive(:client_options).and_return(mock_client_options)
      allow_any_instance_of(described_class).to receive(:authorize).and_return(mock_credentials)

      expect(mock_service).to receive(:authorization=).with(mock_credentials)
      described_class.new(credentials_path: credentials_path, token_path: token_path)
    end
  end

  describe '#authorize' do
    let(:mock_client_id) { double('client_id') }
    let(:mock_token_store) { double('token_store') }
    let(:mock_authorizer) { double('authorizer') }

    before do
      allow(Google::Auth::ClientId).to receive(:from_file).with(credentials_path).and_return(mock_client_id)
      allow(Google::Auth::Stores::FileTokenStore).to receive(:new)
        .with(file: token_path).and_return(mock_token_store)
      allow(Google::Auth::UserAuthorizer).to receive(:new)
        .with(mock_client_id, GmailService::SCOPE, mock_token_store)
        .and_return(mock_authorizer)
    end

    context 'when credentials already exist' do
      it 'returns existing credentials without prompting the user' do
        allow(mock_authorizer).to receive(:get_credentials).with('default').and_return(mock_credentials)

        # Call the real authorize method on a raw (non-stubbed) instance
        raw_client = described_class.allocate
        raw_client.instance_variable_set(:@credentials_path, credentials_path)
        raw_client.instance_variable_set(:@token_path, token_path)

        result = raw_client.authorize
        expect(result).to eq(mock_credentials)
      end
    end

    context 'when no credentials exist' do
      it 'prompts the user, exchanges the code, and returns new credentials' do
        allow(mock_authorizer).to receive(:get_credentials).with('default').and_return(nil)
        allow(mock_authorizer).to receive(:get_authorization_url)
          .with(base_url: GmailService::OOB_URI)
          .and_return('https://auth.example.com/auth')
        allow($stdin).to receive(:gets).and_return("auth_code\n")
        allow(mock_authorizer).to receive(:get_and_store_credentials_from_code)
          .with(user_id: 'default', code: 'auth_code', base_url: GmailService::OOB_URI)
          .and_return(mock_credentials)

        raw_client = described_class.allocate
        raw_client.instance_variable_set(:@credentials_path, credentials_path)
        raw_client.instance_variable_set(:@token_path, token_path)

        result = raw_client.authorize
        expect(result).to eq(mock_credentials)
      end
    end
  end

  describe '#list_messages' do
    let(:message_stub1) { double('msg_ref', id: 'msg_1') }
    let(:message_stub2) { double('msg_ref', id: 'msg_2') }
    let(:list_result) { double('list_result', messages: [message_stub1, message_stub2]) }

    let(:full_message1) { sample_email_message(id: 'msg_1', subject: 'Hello') }
    let(:full_message2) { sample_email_message(id: 'msg_2', subject: 'World') }

    before do
      allow(mock_service).to receive(:list_user_messages)
        .with('me', max_results: 10, q: nil)
        .and_return(list_result)
      allow(mock_service).to receive(:get_user_message)
        .with('me', 'msg_1', format: 'full').and_return(full_message1)
      allow(mock_service).to receive(:get_user_message)
        .with('me', 'msg_2', format: 'full').and_return(full_message2)
    end

    it 'returns an array of message hashes' do
      results = client.list_messages
      expect(results.size).to eq(2)
    end

    it 'maps messages to the expected hash structure' do
      results = client.list_messages
      expect(results.first).to include(:id, :thread_id, :subject, :from, :to, :date, :snippet, :body, :labels)
    end

    it 'uses default max_results of 10' do
      expect(mock_service).to receive(:list_user_messages).with('me', max_results: 10, q: nil).and_return(list_result)
      client.list_messages
    end

    it 'accepts custom max_results and query' do
      allow(mock_service).to receive(:list_user_messages)
        .with('me', max_results: 5, q: 'is:unread')
        .and_return(double('result', messages: []))
      results = client.list_messages(max_results: 5, query: 'is:unread')
      expect(results).to eq([])
    end

    context 'when the result has no messages' do
      it 'returns an empty array' do
        allow(mock_service).to receive(:list_user_messages)
          .with('me', max_results: 10, q: nil)
          .and_return(double('result', messages: nil))
        expect(client.list_messages).to eq([])
      end
    end
  end

  describe '#get_message' do
    let(:message) do
      payload = double('payload',
        headers: sample_email_headers('Subject' => 'Test Subject'),
        body: double('body', data: Base64.urlsafe_encode64('Hello world')),
        parts: nil
      )
      double('message',
        id: 'msg_123',
        thread_id: 'thread_msg_123',
        snippet: 'Test Subject - snippet',
        label_ids: ['INBOX'],
        payload: payload
      )
    end

    before do
      allow(mock_service).to receive(:get_user_message)
        .with('me', 'msg_123', format: 'full')
        .and_return(message)
    end

    it 'returns a hash with the expected keys' do
      result = client.get_message('msg_123')
      expect(result.keys).to contain_exactly(:id, :thread_id, :subject, :from, :to, :date, :snippet, :body, :labels)
    end

    it 'extracts the subject correctly' do
      result = client.get_message('msg_123')
      expect(result[:subject]).to eq('Test Subject')
    end

    it 'extracts from, to, and date from headers' do
      result = client.get_message('msg_123')
      expect(result[:from]).to eq('sender@example.com')
      expect(result[:to]).to eq('recipient@example.com')
      expect(result[:date]).to eq('Mon, 20 Feb 2026 10:00:00 +0000')
    end

    it 'includes the snippet' do
      result = client.get_message('msg_123')
      expect(result[:snippet]).to eq('Test Subject - snippet')
    end

    it 'decodes the body' do
      result = client.get_message('msg_123')
      expect(result[:body]).to eq('Hello world')
    end

    it 'includes the label ids' do
      result = client.get_message('msg_123')
      expect(result[:labels]).to eq(['INBOX'])
    end

    context 'when headers are missing' do
      let(:message) do
        payload = double('payload',
          headers: [],
          body: double('body', data: Base64.urlsafe_encode64('body')),
          parts: nil
        )
        double('message',
          id: 'msg_empty',
          thread_id: 'thread_empty',
          snippet: 'snippet',
          label_ids: [],
          payload: payload
        )
      end

      before do
        allow(mock_service).to receive(:get_user_message)
          .with('me', 'msg_empty', format: 'full')
          .and_return(message)
      end

      it 'falls back to default values for missing headers' do
        result = client.get_message('msg_empty')
        expect(result[:subject]).to eq('(No Subject)')
        expect(result[:from]).to eq('Unknown')
        expect(result[:to]).to eq('Unknown')
        expect(result[:date]).to eq('Unknown')
      end
    end

    context 'with a multipart message' do
      let(:message) { sample_email_message(id: 'msg_multi') }

      let(:multipart_payload) { sample_email_payload(multipart: true) }

      before do
        multi_message = double('message',
          id: 'msg_multi',
          thread_id: 'thread_multi',
          snippet: 'multipart snippet',
          label_ids: ['INBOX'],
          payload: multipart_payload
        )
        allow(mock_service).to receive(:get_user_message)
          .with('me', 'msg_multi', format: 'full')
          .and_return(multi_message)
      end

      it 'joins parts with double newlines' do
        result = client.get_message('msg_multi')
        expect(result[:body]).to eq("Part 1\n\nPart 2")
      end
    end
  end

  describe '#search_messages' do
    it 'delegates to list_messages with the given query' do
      expect(client).to receive(:list_messages).with(max_results: 10, query: 'subject:invoice')
      client.search_messages('subject:invoice')
    end

    it 'accepts a custom max_results' do
      expect(client).to receive(:list_messages).with(max_results: 20, query: 'from:boss@example.com')
      client.search_messages('from:boss@example.com', max_results: 20)
    end
  end

  describe '#get_labels' do
    let(:labels) do
      [
        sample_label(id: 'INBOX', name: 'INBOX', type: 'system'),
        sample_label(id: 'Label_1', name: 'Work', type: 'user')
      ]
    end
    let(:label_result) { double('label_result', labels: labels) }

    before do
      allow(mock_service).to receive(:list_user_labels).with('me').and_return(label_result)
    end

    it 'returns an array of label hashes' do
      result = client.get_labels
      expect(result.size).to eq(2)
    end

    it 'maps labels to hashes with id, name, and type' do
      result = client.get_labels
      expect(result.first).to eq({ id: 'INBOX', name: 'INBOX', type: 'system' })
      expect(result.last).to eq({ id: 'Label_1', name: 'Work', type: 'user' })
    end
  end

  describe '#get_unread_count' do
    before do
      allow(mock_service).to receive(:get_user_label)
        .with('me', 'UNREAD')
        .and_return(double('label_detail', messages_total: 42))
    end

    it 'returns the total number of unread messages' do
      expect(client.get_unread_count).to eq(42)
    end

    context 'when messages_total is nil' do
      before do
        allow(mock_service).to receive(:get_user_label)
          .with('me', 'UNREAD')
          .and_return(double('label_detail', messages_total: nil))
      end

      it 'returns 0' do
        expect(client.get_unread_count).to eq(0)
      end
    end
  end
end

