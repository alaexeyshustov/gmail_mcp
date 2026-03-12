require 'ruby_llm'
require 'ruby_llm/mcp'

# Patch RubyLLM::Chat to handle the case where an LLM returns an unrecognised
# tool name (e.g. a garbled or hallucinated name). Instead of crashing with
# NoMethodError, return an error string so the LLM can self-correct on the next
# turn.
module RubyLLMChatPatch
  def execute_tool(tool_call)
    tool = tools[tool_call.name.to_sym]
    if tool.nil?
      available = tools.keys.join(', ')
      "Error: unknown tool '#{tool_call.name}'. Available tools: #{available}. Please retry using one of the available tool names."
    else
      super
    end
  end
end
RubyLLM::Chat.prepend(RubyLLMChatPatch)

module Pipeline
  # Manages the lifecycle of an MCP client subprocess (stdio transport).
  class McpConnection
    MCP_SERVER_PATH   = File.expand_path('../mcp_server.rb', __dir__)
    TIMEOUT_SECONDS   = ENV.fetch('MCP_TIMEOUT_SECONDS', '120').to_i
    TIMEOUT_MS        = TIMEOUT_SECONDS * 1000

    attr_reader :client, :tools

    def initialize
      @client = RubyLLM::MCP::Client.new(
        name:            'mail',
        transport_type:  :stdio,
        request_timeout: TIMEOUT_MS,
        config: {
          command: 'bundle',
          args:    ['exec', 'ruby', MCP_SERVER_PATH]
        }
      )
      @tools = @client.tools
    end

    def stop
      @client.stop
    end
  end
end
