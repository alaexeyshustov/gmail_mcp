require 'net/imap'
require 'mail'
require 'date'

class YahooMailService
  IMAP_DATE_FORMAT = '%d-%b-%Y'  # e.g. "01-Jan-2024"

  def initialize(host:, port:, username:, password:)
    @host     = host
    @port     = port
    @username = username
    @password = password
    @mutex    = Mutex.new
    @current_mailbox = nil
    connect!
  end

  # List recent emails, optionally filtered and paginated.
  #
  # @param mailbox     [String]  IMAP mailbox to select (default: 'INBOX')
  # @param max_results [Integer] Maximum number of emails to return
  # @param query       [String]  Human-readable search query (Gmail-style subset supported)
  # @param flagged     [Boolean] Filter by flagged status (true = flagged, false = unflagged, nil = all)
  # @param after_date  [Date]    Return only messages on or after this date
  # @param before_date [Date]    Return only messages before this date
  # @param offset      [Integer] Number of messages to skip (for pagination)
  # @return [Array<Hash>]
  def list_messages(mailbox: 'INBOX', max_results: 10, query: nil, flagged: nil,
                    after_date: nil, before_date: nil, offset: 0)
    with_lock do
      ensure_mailbox(mailbox)

      criteria = build_search_criteria(query: query, flagged: flagged, after_date: after_date, before_date: before_date)
      uids = @imap.uid_search(criteria)

      # Most recent first (highest UID = most recent in IMAP)
      uids = uids.sort.reverse

      # Paginate
      uids = uids[offset, max_results] || []

      uids.map { |uid| fetch_and_parse(uid, mailbox) }.compact
    end
  end

  # Fetch a single email by its UID.
  #
  # @param uid     [Integer] IMAP UID of the message
  # @param mailbox [String]  IMAP mailbox containing the message
  # @return [Hash, nil]
  def get_message(uid, mailbox: 'INBOX')
    with_lock do
      ensure_mailbox(mailbox)
      fetch_and_parse(uid, mailbox)
    end
  end

  # Search emails using a human-readable query string.
  #
  # Supported syntax:
  #   from:user@example.com  to:user@example.com  subject:word
  #   is:unread  is:read  is:flagged
  #   after:YYYY-MM-DD  before:YYYY-MM-DD
  #   bare words → full-text search (TEXT)
  #
  # @param query       [String]  Search query
  # @param max_results [Integer] Maximum number of results
  # @param mailbox     [String]  IMAP mailbox to search
  # @return [Array<Hash>]
  def search_messages(query, max_results: 10, mailbox: 'INBOX')
    list_messages(mailbox: mailbox, max_results: max_results, query: query)
  end

  # List all IMAP mailboxes (Yahoo folders).
  #
  # @return [Array<Hash>] Array of {name:, delimiter:, attributes:}
  def get_folders
    with_lock do
      folders = @imap.list('', '*') || []
      folders.map do |mailbox|
        {
          name:       mailbox.name,
          delimiter:  mailbox.delim,
          attributes: Array(mailbox.attr).map(&:to_s)
        }
      end
    end
  end

  # Get the count of unseen messages in a mailbox.
  #
  # @param mailbox [String] IMAP mailbox name
  # @return [Integer]
  def get_unread_count(mailbox: 'INBOX')
    with_lock do
      status = @imap.status(mailbox, ['UNSEEN'])
      status['UNSEEN'] || 0
    end
  end

  # Add or remove IMAP flags/keywords (tags) on a message.
  #
  # @param uid     [Integer]       IMAP UID of the message
  # @param tags    [Array<String>] Flags or keywords to apply (e.g. '\Flagged', '\Seen', 'custom-tag')
  # @param mailbox [String]        IMAP mailbox containing the message
  # @param action  [String]        'add' to add tags, 'remove' to remove them
  # @return [Hash]
  def tag_email(uid, tags:, mailbox: 'INBOX', action: 'add')
    with_lock do
      ensure_mailbox(mailbox)
      imap_action = action == 'remove' ? '-FLAGS' : '+FLAGS'
      # Convert tags to proper IMAP format:
      # System flags starting with \ become symbols (e.g., '\Flagged' -> :Flagged)
      # Custom keywords remain as strings
      imap_flags = tags.map do |tag|
        tag.start_with?('\\') ? tag[1..].to_sym : tag
      end
      @imap.uid_store(uid, imap_action, imap_flags)
      { uid: uid, action: action, tags: tags, mailbox: mailbox }
    end
  end

  # Close the IMAP connection cleanly.
  def disconnect
    return unless @imap
    @imap.logout rescue nil
    @imap.disconnect rescue nil
  rescue StandardError
    # ignore errors during teardown
  ensure
    @imap = nil
  end

  private

  def connect!
    @imap = Net::IMAP.new(@host, port: @port, ssl: true)
    @imap.login(@username, @password)
    @current_mailbox = nil
  end

  def ensure_mailbox(mailbox)
    return if @current_mailbox == mailbox

    @imap.select(mailbox)
    @current_mailbox = mailbox
  end

  def with_reconnect(&block)
    block.call
  rescue Net::IMAP::ByeResponseError, IOError, Errno::ECONNRESET, Errno::EPIPE => e
    $stderr.puts "IMAP connection lost (#{e.class}: #{e.message}), reconnecting..."
    connect!
    block.call
  end

  def with_lock(&block)
    @mutex.synchronize { with_reconnect(&block) }
  end

  # Fetch a single message by UID and parse it into a hash.
  def fetch_and_parse(uid, mailbox)
    data = @imap.uid_fetch(uid, %w[RFC822 FLAGS UID])
    return nil if data.nil? || data.empty?

    attrs = data.first.attr
    raw   = attrs['RFC822']
    return nil if raw.nil? || raw.empty?

    mail = Mail.new(raw)
    body = extract_body(mail)

    {
      id:      uid,
      subject: decode_header(mail.subject) || '(No Subject)',
      from:    Array(mail.from).join(', ').then { |v| v.empty? ? 'Unknown' : v },
      to:      Array(mail.to).join(', ').then   { |v| v.empty? ? 'Unknown' : v },
      date:    mail.date&.to_s || 'Unknown',
      snippet: body[0, 200],
      body:    body,
      folders: [mailbox]
    }
  rescue StandardError => e
    $stderr.puts "Warning: failed to parse message UID #{uid}: #{e.message}"
    nil
  end

  # Extract plain-text body from a Mail::Message, falling back to HTML.
  def extract_body(mail)
    if mail.multipart?
      # Prefer text/plain
      plain = mail.parts.find { |p| p.mime_type == 'text/plain' }
      return decode_part(plain) if plain

      # Fall back to text/html (strip tags)
      html = mail.parts.find { |p| p.mime_type == 'text/html' }
      return strip_html(decode_part(html)) if html

      # Recurse into nested multiparts
      mail.parts.filter_map { |p| extract_body(p) }.reject(&:empty?).join("\n\n")
    elsif mail.mime_type == 'text/html'
      strip_html(decode_part(mail))
    else
      decode_part(mail)
    end
  end

  def decode_part(part)
    return '' unless part

    body = part.respond_to?(:decoded) ? part.decoded : part.body.decoded
    body.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?').strip
  rescue StandardError
    ''
  end

  def strip_html(html)
    html.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip
  end

  # Decode RFC 2047 encoded header values (e.g. =?UTF-8?B?...?=)
  def decode_header(value)
    return nil if value.nil?
    value.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  rescue StandardError
    value.to_s
  end

  # Build an IMAP SEARCH criteria array from query + date filters + flagged status.
  def build_search_criteria(query: nil, flagged: nil, after_date: nil, before_date: nil)
    criteria = build_date_criteria(after_date, before_date)
    
    # Add flagged filter if specified
    if flagged == true
      criteria << 'FLAGGED'
    elsif flagged == false
      criteria << 'UNFLAGGED'
    end
    
    criteria += parse_query_criteria(query) if query

    criteria.empty? ? ['ALL'] : criteria
  end

  def build_date_criteria(after_date, before_date)
    result = []
    result += ['SINCE', after_date.strftime(IMAP_DATE_FORMAT)]  if after_date
    result += ['BEFORE', before_date.strftime(IMAP_DATE_FORMAT)] if before_date
    result
  end

  # Translate a human-readable query string into IMAP SEARCH criteria tokens.
  #
  # Supported operators:
  #   from:addr, to:addr, subject:word, is:unread, is:read, is:flagged,
  #   after:YYYY-MM-DD, before:YYYY-MM-DD, bare words → TEXT
  def parse_query_criteria(query)
    criteria  = []
    bare_words = []

    query.split(/\s+/).each do |token|
      case token
      when /\Afrom:(.+)\z/i
        criteria += ['FROM', $1]
      when /\Ato:(.+)\z/i
        criteria += ['TO', $1]
      when /\Asubject:(.+)\z/i
        criteria += ['SUBJECT', $1]
      when /\Ais:unread\z/i
        criteria << 'UNSEEN'
      when /\Ais:read\z/i
        criteria << 'SEEN'
      when /\Ais:flagged\z/i
        criteria << 'FLAGGED'
      when /\Aafter:(\d{4}[-\/]\d{2}[-\/]\d{2})\z/i
        date = Date.parse($1.tr('/', '-'))
        criteria += ['SINCE', date.strftime(IMAP_DATE_FORMAT)]
      when /\Abefore:(\d{4}[-\/]\d{2}[-\/]\d{2})\z/i
        date = Date.parse($1.tr('/', '-'))
        criteria += ['BEFORE', date.strftime(IMAP_DATE_FORMAT)]
      when /\Ahas:attachment\z/i
        # Best-effort: search for multipart messages
        criteria += ['HEADER', 'Content-Type', 'multipart']
      else
        bare_words << token
      end
    end

    # Join bare words into a single TEXT search
    criteria += ['TEXT', bare_words.join(' ')] unless bare_words.empty?

    criteria
  end
end

