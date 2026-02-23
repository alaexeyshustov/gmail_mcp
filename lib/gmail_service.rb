require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'

class GmailService
  attr_reader :service

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'Gmail MCP Server'
  SCOPE = ['https://www.googleapis.com/auth/gmail.readonly'].freeze

  def initialize(credentials_path:, token_path:)
    @credentials_path = credentials_path
    @token_path = token_path
    @service = Google::Apis::GmailV1::GmailService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
  end

  def authorize
    client_id = Google::Auth::ClientId.from_file(@credentials_path)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: @token_path)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)

    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      $stderr.puts 'Open the following URL in the browser and enter the resulting code after authorization:'
      $stderr.puts url
      $stderr.print 'Code: '
      code = $stdin.gets.chomp
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end

    credentials
  end

  def list_messages(max_results: 10, query: nil)
    result = @service.list_user_messages('me', max_results: max_results, q: query)
    messages = result.messages || []

    messages.map do |message|
      get_message(message.id)
    end
  end

  def get_message(message_id)
    message = @service.get_user_message('me', message_id, format: 'full')

    headers = message.payload.headers
    subject = headers.find { |h| h.name == 'Subject' }&.value || '(No Subject)'
    from = headers.find { |h| h.name == 'From' }&.value || 'Unknown'
    to = headers.find { |h| h.name == 'To' }&.value || 'Unknown'
    date = headers.find { |h| h.name == 'Date' }&.value || 'Unknown'

    body = extract_body(message.payload)

    {
      id: message.id,
      thread_id: message.thread_id,
      subject: subject,
      from: from,
      to: to,
      date: date,
      snippet: message.snippet,
      body: body,
      labels: message.label_ids || []
    }
  end

  def search_messages(query, max_results: 10)
    list_messages(max_results: max_results, query: query)
  end

  def get_labels
    result = @service.list_user_labels('me')
    result.labels.map do |label|
      {
        id: label.id,
        name: label.name,
        type: label.type
      }
    end
  end

  def get_unread_count
    result = @service.get_user_label('me', 'UNREAD')
    result.messages_total || 0
  end

  private

  def extract_body(payload)
    if payload.parts && !payload.parts.empty?
      # Collect all text/plain parts first (recursive)
      text_parts = collect_parts(payload, 'text/plain')
      return text_parts.join("\n\n") unless text_parts.empty?

      # Fall back to text/html parts
      html_parts = collect_parts(payload, 'text/html')
      return html_parts.join("\n\n") unless html_parts.empty?

      # Last resort: recurse through all parts and join non-empty bodies
      payload.parts.filter_map { |part|
        body = extract_body(part)
        body unless body.empty?
      }.join("\n\n")
    elsif payload.body&.data && !payload.body.data.empty?
      decode_body(payload.body.data)
    else
      ''
    end
  end

  # Recursively collect all parts matching mime_type that have body data
  def collect_parts(payload, mime_type)
    return [] unless payload.parts

    payload.parts.flat_map do |part|
      results = []
      if part.respond_to?(:mime_type) && part.mime_type == mime_type && part.body&.data
        results << decode_body(part.body.data)
      end
      results + collect_parts(part, mime_type)
    end
  end

  def decode_body(data)
    return '' if data.nil? || data.empty?

    # The google-apis-gmail_v1 gem automatically base64url-decodes body.data
    # when deserializing the API response, so data is already plain text here.
    data.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  rescue StandardError
    ''
  end

end

