#!/usr/bin/env ruby

require 'yaml'
require 'fast_mcp'

require_relative 'gmail_service'
require_relative 'tools/list_emails'
require_relative 'tools/get_email'
require_relative 'tools/search_emails'
require_relative 'tools/get_labels'
require_relative 'tools/get_unread_count'

# Load configuration
root = File.expand_path('../../', __FILE__)
config = YAML.load_file(File.join(root, 'config.yml'))

# Initialize a single shared GmailService instance.
# This avoids repeated OAuth initialization and keeps token refresh simple.
gmail = GmailService.new(
  credentials_path: File.join(root, config['credentials_path']),
  token_path: File.join(root, config['token_path'])
)

# Inject the shared service into each tool class
[
  Tools::ListEmails,
  Tools::GetEmail,
  Tools::SearchEmails,
  Tools::GetLabels,
  Tools::GetUnreadCount
].each { |tool_class| tool_class.gmail_service = gmail }

# Create and configure the MCP server
# FastMcp::Server creates a FastMcp::Logger by default which suppresses stdout
# output when using the stdio transport — do not pass a plain Logger here.
server = FastMcp::Server.new(
  name: 'gmail',
  version: '1.0.0'
)

# Register all tools
server.register_tools(
  Tools::ListEmails,
  Tools::GetEmail,
  Tools::SearchEmails,
  Tools::GetLabels,
  Tools::GetUnreadCount
)

# Start the server using stdio transport (default for local MCP servers)
server.start
