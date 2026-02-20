require 'mcp'
require 'json'
require 'yaml'
require_relative 'lib/gmail_service'
require_relative 'lib/tools/list_emails'

CONFIG_PATH = File.expand_path('../config.yml', __FILE__)
_config = YAML.load_file(CONFIG_PATH)
CREDENTIALS_PATH = File.expand_path(_config['credentials_path'])
TOKEN_PATH = File.expand_path(_config['token_path'])

gmail = GmailService.new(
  credentials_path: CREDENTIALS_PATH,
  token_path: TOKEN_PATH
)

configuration = MCP::Configuration.new
configuration.exception_reporter = ->(exception, server_context) {
  STDERR.puts "Exception: #{exception.message}"
  STDERR.puts exception.backtrace.join("\n")
}

configuration.instrumentation_callback = ->(data) {
  # no-op
}

tools = [ListEmails]

# Set up the server
server = MCP::Server.new(
  name: "GMAIL_MCP_SERVER",
  version: "1.0.0",
  tools: tools,
  configuration:,
  )

server.server_context = { gmail: gmail }

# Create and start the transport
transport = MCP::Server::Transports::StdioTransport.new(server)
STDERR.puts 'Starting Gmail MCP Server...'
transport.open
