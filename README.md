# Gmail MCP Server

A local [Model Context Protocol (MCP)](https://modelcontextprotocol.io) server
written in Ruby that exposes your Gmail inbox as tools for AI agents. Integrates
with **GitHub Copilot agent mode** in JetBrains IDEs and VS Code.

## What it does

The server runs as a local child process. GitHub Copilot launches it via
stdio and calls its tools in response to natural-language prompts like
_"Show me my unread emails"_ or _"Search for invoices from last week"_.

### Available tools

| Tool | Description | Arguments |
|------|-------------|-----------|
| `list_emails` | List recent emails from the inbox | `max_results` (default 10), `query` (optional Gmail search) |
| `get_email` | Fetch the full content of a specific email | `message_id` (required) |
| `search_emails` | Search Gmail with a query string | `query` (required), `max_results` (default 10) |
| `get_labels` | List all Gmail labels (system + user-created) | — |
| `get_unread_count` | Get the total number of unread emails | — |

All tools are **read-only** (`gmail.readonly` OAuth scope).

---

## Prerequisites

- Ruby ≥ 3.1
- Bundler
- A Google Cloud project with the **Gmail API** enabled
- OAuth 2.0 Desktop App credentials (`credentials.json`)

---

## Setup

### 1. Clone and install dependencies

```bash
git clone <repo-url> gmail_mcp
cd gmail_mcp
bundle install
```

### 2. Google Cloud credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project (or use an existing one)
3. Enable the **Gmail API** under *APIs & Services → Library*
4. Go to *APIs & Services → Credentials → Create Credentials → OAuth client ID*
5. Choose **Desktop app**, download the JSON
6. Save it as `credentials.json` in the project root

See `credentials.json.example` for the expected format.

### 3. Authorise with Gmail (one-time)

```bash
bundle exec ruby -e "
  require_relative 'lib/gmail_service'
  GmailService.new(credentials_path: 'credentials.json', token_path: 'token.yaml')
"
```

This will:
1. Print an authorisation URL — open it in your browser
2. Approve access in the Google consent screen
3. Paste the authorisation code back into the terminal

`token.yaml` is created and stored in the project root. The server refreshes
access tokens automatically from this point on.

---

## Running the server

```bash
bundle exec ruby mcp_server.rb
```

The server reads JSON-RPC requests from **stdin** and writes responses to
**stdout** (stdio MCP transport). It is normally started automatically by the
IDE via `.mcp.json` — you do not need to run it manually.

---

## JetBrains / GitHub Copilot integration

The `.mcp.json` file in the project root is already configured:

```json
{
  "mcpServers": {
    "gmail": {
      "command": "bundle",
      "args": ["exec", "ruby", "mcp_server.rb"],
      "cwd": "/Users/aleksey.shustov/gmail_mcp",
      "env": {}
    }
  }
}
```

JetBrains IDEs (RubyMine, IntelliJ IDEA, etc.) pick this up automatically
when the project is open and GitHub Copilot is installed. See
[COPILOT_INTEGRATION.md](COPILOT_INTEGRATION.md) for VS Code setup and
troubleshooting.

### Try it in Copilot Chat (agent mode)

```
Show me my 5 most recent emails
How many unread emails do I have?
Search for emails from john@example.com
Find emails with subject containing "invoice"
List my Gmail labels
```

---

## Testing

```bash
bundle exec rspec
```

**48 examples, 0 failures.**

The test suite uses RSpec with WebMock — no real API calls are made during
tests. Gmail API responses are mocked via `instance_double`.

---

## Manual protocol test

You can exercise the server directly from the terminal:

```bash
# List all registered tools
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' \
  | bundle exec ruby mcp_server.rb

# Get unread count (hits the real Gmail API)
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_unread_count","arguments":{}}}\n' \
  | bundle exec ruby mcp_server.rb

# Search emails
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"search_emails","arguments":{"query":"is:unread","max_results":3}}}\n' \
  | bundle exec ruby mcp_server.rb
```

---

## Project structure

```
gmail_mcp/
├── .mcp.json                    # JetBrains/Copilot MCP server config
├── mcp_server.rb                # Entry point — creates & starts MCP server
├── config.yml                   # credentials_path / token_path
├── credentials.json             # Google OAuth client credentials (not committed)
├── token.yaml                   # OAuth refresh token (not committed)
├── Gemfile
├── lib/
│   ├── gmail_service.rb         # Gmail API wrapper (OAuth, list, get, search)
│   └── tools/
│       ├── list_emails.rb       # MCP tool: list_emails
│       ├── get_email.rb         # MCP tool: get_email
│       ├── search_emails.rb     # MCP tool: search_emails
│       ├── get_labels.rb        # MCP tool: get_labels
│       └── get_unread_count.rb  # MCP tool: get_unread_count
└── spec/
    ├── lib/
    │   ├── gmail_service_spec.rb
    │   └── tools/               # One spec per tool
    └── support/
        └── gmail_fixtures.rb
```

---

## Key dependencies

| Gem | Version | Purpose |
|-----|---------|---------|
| `fast-mcp` | ~> 1.6 | MCP server (stdio transport, tool DSL, JSON-RPC 2.0) |
| `google-apis-gmail_v1` | 0.47.0 | Official Gmail REST API client |
| `googleauth` | 1.16.1 | OAuth 2.0 with automatic token refresh |
| `pstore` | latest | Persistent token storage (used by `googleauth`) |

---

## Security notes

- `credentials.json` and `token.yaml` contain secrets — **do not commit them**.
  Add them to `.gitignore`.
- The server uses the `gmail.readonly` scope only — it cannot send, delete,
  or modify any email.
- The MCP server binds to **stdio only** — no network port is opened.

