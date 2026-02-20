class ListEmails < MCP::Tool
  description "List recent emails from Gmail inbox"
  input_schema(
    properties: {
      max_results: {
        type: "integer",
        description: "Maximum number of emails to retrieve (default: 10, max: 50)",
        minimum: 1,
        maximum: 50
      },
      query: {
        type: "string",
        description: "Optional Gmail search query to filter emails (e.g., 'is:unread', 'from:user@example.com')"
      }
    }
  )

  class << self
    def call(max_results: 10, query: nil, server_context: nil)
      gmail = server_context[:gmail]
      messages = gmail.list_messages(max_results: max_results, query: query)

      MCP::Tool::Response.new([{
        type: "text",
        text: JSON.pretty_generate({
          total: messages.length,
          emails: messages
        })
      }])
    end
  end
end


