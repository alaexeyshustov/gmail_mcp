require 'mail'
require 'net/imap'

module SpecHelpers
  module YahooMailFixtures
    # ---------------------------------------------------------------------------
    # Raw RFC 2822 email strings
    # ---------------------------------------------------------------------------

    def plain_text_raw_email(overrides = {})
      subject = overrides.fetch(:subject, 'Test Email Subject')
      from    = overrides.fetch(:from,    'sender@example.com')
      to      = overrides.fetch(:to,      'recipient@example.com')
      date    = overrides.fetch(:date,    'Mon, 20 Feb 2026 10:00:00 +0000')
      body    = overrides.fetch(:body,    'This is the email body.')

      <<~EMAIL
        From: #{from}
        To: #{to}
        Subject: #{subject}
        Date: #{date}
        MIME-Version: 1.0
        Content-Type: text/plain; charset=UTF-8
        Content-Transfer-Encoding: 7bit

        #{body}
      EMAIL
    end

    def multipart_raw_email(overrides = {})
      subject    = overrides.fetch(:subject,    'Multipart Email')
      from       = overrides.fetch(:from,       'sender@example.com')
      to         = overrides.fetch(:to,         'recipient@example.com')
      date       = overrides.fetch(:date,       'Mon, 20 Feb 2026 10:00:00 +0000')
      plain_body = overrides.fetch(:plain_body, 'Plain text part.')
      html_body  = overrides.fetch(:html_body,  '<p>HTML part.</p>')

      <<~EMAIL
        From: #{from}
        To: #{to}
        Subject: #{subject}
        Date: #{date}
        MIME-Version: 1.0
        Content-Type: multipart/alternative; boundary="boundary123"

        --boundary123
        Content-Type: text/plain; charset=UTF-8
        Content-Transfer-Encoding: 7bit

        #{plain_body}
        --boundary123
        Content-Type: text/html; charset=UTF-8
        Content-Transfer-Encoding: 7bit

        #{html_body}
        --boundary123--
      EMAIL
    end

    def html_only_raw_email(overrides = {})
      subject = overrides.fetch(:subject, 'HTML Only Email')
      from    = overrides.fetch(:from,    'sender@example.com')
      to      = overrides.fetch(:to,      'recipient@example.com')
      date    = overrides.fetch(:date,    'Mon, 20 Feb 2026 10:00:00 +0000')
      body    = overrides.fetch(:body,    '<p>Hello <b>World</b></p>')

      <<~EMAIL
        From: #{from}
        To: #{to}
        Subject: #{subject}
        Date: #{date}
        MIME-Version: 1.0
        Content-Type: text/html; charset=UTF-8
        Content-Transfer-Encoding: 7bit

        #{body}
      EMAIL
    end

    # ---------------------------------------------------------------------------
    # Net::IMAP::FetchData double
    # ---------------------------------------------------------------------------

    def fetch_data_double(uid: 101, raw_email: nil, flags: [])
      raw = raw_email || plain_text_raw_email
      attrs = {
        'RFC822' => raw,
        'FLAGS'  => flags,
        'UID'    => uid
      }
      double('Net::IMAP::FetchData', attr: attrs)
    end

    # ---------------------------------------------------------------------------
    # Net::IMAP::MailboxList double
    # ---------------------------------------------------------------------------

    def mailbox_list_double(name: 'INBOX', delim: '/', attr: [])
      double('Net::IMAP::MailboxList', name: name, delim: delim, attr: attr)
    end

    def sample_folders
      [
        mailbox_list_double(name: 'INBOX',         delim: '/', attr: []),
        mailbox_list_double(name: 'Sent',           delim: '/', attr: []),
        mailbox_list_double(name: 'Drafts',         delim: '/', attr: []),
        mailbox_list_double(name: 'Trash',          delim: '/', attr: [:Noselect]),
        mailbox_list_double(name: 'Bulk Mail',      delim: '/', attr: [])
      ]
    end

    # ---------------------------------------------------------------------------
    # Expected message hash (matches YahooMailService output)
    # ---------------------------------------------------------------------------

    def sample_message_hash(overrides = {})
      {
        id:      overrides.fetch(:id,      101),
        subject: overrides.fetch(:subject, 'Test Email Subject'),
        from:    overrides.fetch(:from,    'sender@example.com'),
        to:      overrides.fetch(:to,      'recipient@example.com'),
        date:    overrides.fetch(:date,    anything),
        snippet: overrides.fetch(:snippet, anything),
        body:    overrides.fetch(:body,    anything),
        folders: overrides.fetch(:folders, ['INBOX'])
      }
    end
  end
end

RSpec.configure do |config|
  config.include SpecHelpers::YahooMailFixtures
end

