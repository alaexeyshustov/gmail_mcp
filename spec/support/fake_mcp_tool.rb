# Lightweight stand-in for RubyLLM::MCP::Tool used in pipeline specs.
# Satisfies the interface required by RubyLLM::Chat#with_tool (name, description,
# params_schema) without spawning a real MCP subprocess.
FakeMcpTool = Struct.new(:name) do
  def description    = ''
  def params_schema  = { 'type' => 'object', 'properties' => {} }
  def parameters     = []
  def provider_params = {}
  def execute(**)    = {}
end
