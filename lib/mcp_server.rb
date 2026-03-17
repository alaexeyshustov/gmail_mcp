#!/usr/bin/env ruby

require 'dotenv/load'
require 'fast_mcp'
require_relative 'loader'

# ---------------------------------------------------------------------------
# Build the provider registry — register only configured providers
# ---------------------------------------------------------------------------
registry = ProviderRegistry.new

root = File.expand_path('../../', __FILE__)

credentials_path = File.join(root, ENV.fetch('CREDENTIALS_PATH', 'credentials.json'))
token_path       = File.join(root, ENV.fetch('TOKEN_PATH', 'token.yaml'))

if File.exist?(credentials_path)
  gmail_service = GmailService.new(
    credentials_path: credentials_path,
    token_path:       token_path
  )
  registry.register('gmail', Adapters::GmailAdapter.new(gmail_service))
else
  $stderr.puts "INFO: Gmail credentials not found at #{credentials_path} — Gmail provider disabled."
end

yahoo_username = ENV['YAHOO_USERNAME']
yahoo_password = ENV['YAHOO_APP_PASSWORD']

if yahoo_username && !yahoo_username.strip.empty? &&
   yahoo_password && !yahoo_password.strip.empty?
  yahoo_service = YahooMailService.new(
    host:     ENV.fetch('YAHOO_IMAP_HOST', 'imap.mail.yahoo.com'),
    port:     ENV.fetch('YAHOO_IMAP_PORT', '993').to_i,
    username: yahoo_username,
    password: yahoo_password
  )
  at_exit { yahoo_service.disconnect }
  registry.register('yahoo', Adapters::YahooAdapter.new(yahoo_service))
else
  $stderr.puts "INFO: YAHOO_USERNAME or YAHOO_APP_PASSWORD not set — Yahoo provider disabled."
end

if registry.providers.empty?
  $stderr.puts "ERROR: No email providers configured. Set up Gmail or Yahoo credentials."
  exit 1
end

# ---------------------------------------------------------------------------
# Inject registry into all tools
# ---------------------------------------------------------------------------
ALL_TOOLS = [
  Tools::ListEmails,
  Tools::GetEmail,
  Tools::SearchEmails,
  Tools::GetLabels,
  Tools::GetUnreadCount,
  Tools::AddLabels,
  Tools::ClassifyEmails,
  Tools::ManageCsv
].freeze

ALL_TOOLS.each { |tool_class| tool_class.registry = registry }

# Initialize the email classifier (works across providers)
Tools::ClassifyEmails.classifier = EmailClassifier.new(
  api_key: ENV.fetch('MISTRAL_API_KEY', '')
)

# ---------------------------------------------------------------------------
# Create and start the MCP server
# FastMcp::Server creates a FastMcp::Logger by default which suppresses stdout
# output when using the stdio transport — do not pass a plain Logger here.
# ---------------------------------------------------------------------------
server = FastMcp::Server.new(
  name:    'mail',
  version: '2.0.0'
)

server.register_tools(*ALL_TOOLS)
server.start
