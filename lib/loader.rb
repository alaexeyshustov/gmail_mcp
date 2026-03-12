require 'zeitwerk'

loader = Zeitwerk::Loader.new
loader.tag = 'mail_mcp'

loader.push_dir(__dir__)

# lib/services/ files define top-level constants (GmailService, GmailAuth,
# YahooMailService) rather than Services::* — collapse the directory so
# Zeitwerk doesn't expect a Services:: namespace.
loader.collapse("#{__dir__}/services")

# These files are entry-points / setup scripts, not autoloadable constants.
loader.ignore("#{__dir__}/loader.rb")
loader.ignore("#{__dir__}/mcp_server.rb")

loader.setup


