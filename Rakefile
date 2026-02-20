# frozen_string_literal: true

require 'rspec/core/rake_task'
require_relative 'bin/gmail_mcp'

# RSpec test tasks
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = ['--format documentation', '--color']
end

desc 'Setup Gmail MCP Server (create directories, check credentials, install dependencies)'
task :setup do
  GmailMCP::CLI::Commands::Setup.new.call
end

desc 'Test the Gmail integration without running the full MCP server'
task :test do
  GmailMCP::CLI::Commands::Test.new.call
end

desc 'Start the MCP server'
task :server do
  GmailMCP::CLI::Commands::Server.new.call
end

desc 'Reset authorization (delete stored token)'
task :reset do
  GmailMCP::CLI::Commands::Reset.new.call
end

desc 'Show current Gmail MCP configuration and authorization status'
task :status do
  GmailMCP::CLI::Commands::Status.new.call
end

task default: :spec

