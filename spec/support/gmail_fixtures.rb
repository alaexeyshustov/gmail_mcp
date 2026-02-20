# frozen_string_literal: true

require 'base64'

module SpecHelpers
  module GmailFixtures
    def sample_email_headers(overrides = {})
      defaults = {
        'Subject' => 'Test Email Subject',
        'From' => 'sender@example.com',
        'To' => 'recipient@example.com',
        'Date' => 'Mon, 20 Feb 2026 10:00:00 +0000'
      }

      defaults.merge(overrides).map do |name, value|
        double('header', name: name, value: value)
      end
    end

    def sample_email_payload(body_text: 'Test email body', multipart: false)
      if multipart
        parts = [
          double('part',
            body: double('body', data: Base64.urlsafe_encode64('Part 1')),
            parts: nil
          ),
          double('part',
            body: double('body', data: Base64.urlsafe_encode64('Part 2')),
            parts: nil
          )
        ]

        double('payload',
          headers: sample_email_headers,
          body: double('body', data: nil),
          parts: parts
        )
      else
        double('payload',
          headers: sample_email_headers,
          body: double('body', data: Base64.urlsafe_encode64(body_text)),
          parts: nil
        )
      end
    end

    def sample_email_message(id: 'msg_123', subject: 'Test Subject', body_text: 'Test body')
      double('message',
        id: id,
        thread_id: "thread_#{id}",
        snippet: "#{subject} - snippet",
        label_ids: ['INBOX'],
        payload: sample_email_payload(body_text: body_text)
      )
    end

    def sample_label(id: 'INBOX', name: 'INBOX', type: 'system')
      double('label', id: id, name: name, type: type)
    end

    def encode_body(text)
      Base64.urlsafe_encode64(text)
    end
  end
end

RSpec.configure do |config|
  config.include SpecHelpers::GmailFixtures
end

