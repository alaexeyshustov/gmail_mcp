# Mail MCP Server

A local [Model Context Protocol (MCP)](https://modelcontextprotocol.io) server
written in Ruby that exposes **Gmail and Yahoo Mail** as unified tools for AI
agents. Integrates with **GitHub Copilot agent mode** in VS Code and JetBrains
IDEs.

## What it does

The server runs as a local child process. GitHub Copilot launches it via stdio
and calls its tools in response to natural-language prompts like _"Show me my
unread emails"_ or _"Classify my last 20 emails"_.

Both providers are supported simultaneously. Every tool (except
`classify_emails`) requires a `provider` argument — `"gmail"` or `"yahoo"`.
Only providers for which credentials are present are registered at startup.

### Available tools

| Tool               | Description                                          | Key arguments                                                                                                       |
| ------------------ | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `list_emails`      | List recent emails from the inbox                    | `provider` (required), `max_results`, `query`, `label`, `mailbox`, `after_date`, `before_date`, `flagged`, `offset` |
| `get_email`        | Fetch the full content of a specific email           | `provider` (required), `message_id` (required), `mailbox`                                                           |
| `search_emails`    | Search emails with a query string                    | `provider` (required), `query` (required), `max_results`, `mailbox`                                                 |
| `get_labels`       | List all labels (Gmail) or folders (Yahoo)           | `provider` (required)                                                                                               |
| `get_unread_count` | Get the number of unread emails                      | `provider` (required), `mailbox`                                                                                    |
| `add_labels`       | Add labels (Gmail) or IMAP flags (Yahoo) to an email | `provider` (required), `message_id` (required), `label_ids` (required), `mailbox`                                   |
| `classify_emails`  | Classify emails by subject line using AI             | `emails` — array of `{id, title}` objects                                                                           |

Gmail uses the `gmail.modify` OAuth scope — read and label modification, no
send or delete.

---

## Prerequisites

- Ruby ≥ 3.1
- Bundler
- **Gmail**: A Google Cloud project with the Gmail API enabled and OAuth 2.0
  Desktop App credentials (`credentials.json`)
- **Yahoo Mail**: A Yahoo account with an
  [app password](https://help.yahoo.com/kb/generate-third-party-passwords-sln15241.html)
  generated (IMAP access)
- **Email classification**: A [Mistral AI](https://mistral.ai) API key

At least one provider must be configured — the server exits with an error if
neither is available.

---

## Setup

### 1. Clone and install dependencies

```bash
git clone <repo-url> mail_mcp
cd mail_mcp
bundle install
```

### 2. Configure environment variables

Copy `.env.example` to `.env` and fill in the values:

```bash
cp .env.example .env
```

```dotenv
# Gmail provider (OAuth 2.0)
CREDENTIALS_PATH=credentials.json
TOKEN_PATH=token.yaml

# Yahoo provider (IMAP with app password)
YAHOO_USERNAME=your-yahoo-address@yahoo.com
YAHOO_APP_PASSWORD=your-app-password-here
YAHOO_IMAP_HOST=imap.mail.yahoo.com
YAHOO_IMAP_PORT=993

# Email classifier (Mistral)
MISTRAL_API_KEY=your-mistral-api-key-here
```

### 3. Gmail: Google Cloud credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project (or use an existing one)
3. Enable the **Gmail API** under _APIs & Services → Library_
4. Go to _APIs & Services → Credentials → Create Credentials → OAuth client ID_
5. Choose **Desktop app**, download the JSON
6. Save it as `credentials.json` in the project root

See `credentials.json.example` for the expected format.

### 4. Gmail: Authorise (one-time OAuth flow)

```bash
bin/cli setup
```

This checks for `credentials.json`, opens a browser-based OAuth consent screen,
and writes `token.yaml`. The server refreshes access tokens automatically from
this point on.

### 5. Yahoo: No extra steps

Set `YAHOO_USERNAME` and `YAHOO_APP_PASSWORD` in `.env` — the adapter
establishes a persistent IMAP connection on first use.

---

## Running the server

```bash
bundle exec ruby lib/mcp_server.rb
```

The server reads JSON-RPC requests from **stdin** and writes responses to
**stdout** (stdio MCP transport). It is normally started automatically by the
IDE via `.mcp.json` — you do not need to run it manually.

---

## GitHub Copilot / IDE integration

The `.mcp.json` file in the project root is already configured:

```json
{
  "mcpServers": {
    "mail": {
      "command": "./bin/cli",
      "args": ["server"],
      "env": {}
    }
  }
}
```

JetBrains IDEs and VS Code pick this up automatically when the project is open
and GitHub Copilot is installed. See
[COPILOT_INTEGRATION.md](COPILOT_INTEGRATION.md) for detailed VS Code setup and
troubleshooting.

### Try it in Copilot Chat (agent mode)

```
Show me my 5 most recent Gmail emails
How many unread Yahoo emails do I have?
Search Gmail for emails from john@example.com
List my Gmail labels
Flag message 12345 as STARRED in Gmail
Classify these emails by subject: [{"id":"1","title":"Invoice #42"},{"id":"2","title":"Team standup"}]
```

---

## CLI commands

| Command          | Description                                                   |
| ---------------- | ------------------------------------------------------------- |
| `bin/cli setup`  | Check credentials, install dependencies, run Gmail OAuth flow |
| `bin/cli test`   | Live integration test against the real Gmail API              |
| `bin/cli status` | Show which providers are configured and reachable             |
| `bin/cli reset`  | Delete `token.yaml` to force re-authorisation                 |
| `bin/cli server` | Start the MCP server (used by `.mcp.json`)                    |

---

## Testing

```bash
bundle exec rspec
```

The test suite uses RSpec with WebMock — no real API or IMAP calls are made.
Gmail responses are mocked via VCR cassettes and `instance_double`; Yahoo
responses use `instance_double(Net::IMAP)`.

---

## Manual protocol test

```bash
# List all registered tools
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' \
  | bundle exec ruby lib/mcp_server.rb

# Get unread count (hits the real Gmail API)
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_unread_count","arguments":{"provider":"gmail"}}}\n' \
  | bundle exec ruby lib/mcp_server.rb

# Search Gmail emails
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"search_emails","arguments":{"provider":"gmail","query":"is:unread","max_results":3}}}\n' \
  | bundle exec ruby lib/mcp_server.rb
```

---

## Project structure

```
mail_mcp/
├── .mcp.json                        # IDE / Copilot MCP server config
├── .env                             # Environment variables (not committed)
├── .env.example                     # Environment variable template
├── credentials.json                 # Google OAuth client credentials (not committed)
├── token.yaml                       # OAuth refresh token (not committed)
├── Gemfile
├── bin/
│   └── cli                          # Dry::CLI entry point (setup, test, reset, status, server)
└── lib/
    ├── mcp_server.rb                # Entry point — boots adapters, registers tools
    ├── provider_registry.rb         # { "gmail" => GmailAdapter, "yahoo" => YahooAdapter }
    ├── email_classifier.rb          # Mistral-based classification via ruby_llm
    ├── adapters/
    │   ├── base_adapter.rb          # Abstract interface all adapters must implement
    │   ├── gmail_adapter.rb         # Wraps GmailService
    │   └── yahoo_adapter.rb         # Wraps YahooMailService
    ├── services/
    │   ├── gmail_service.rb         # Gmail API wrapper (OAuth, list, get, search, labels)
    │   ├── gmail_auth.rb            # Google OAuth2 loopback flow
    │   └── yahoo_mail_service.rb    # Yahoo IMAP wrapper (Net::IMAP, persistent connection)
    └── tools/                       # One file per MCP tool — each requires provider: argument
        ├── list_emails.rb
        ├── get_email.rb
        ├── search_emails.rb
        ├── get_labels.rb
        ├── get_unread_count.rb
        ├── add_labels.rb
        └── classify_emails.rb
```

---

## Key dependencies

| Gem                    | Purpose                                              |
| ---------------------- | ---------------------------------------------------- |
| `fast-mcp` ~> 1.6      | MCP server (stdio transport, tool DSL, JSON-RPC 2.0) |
| `google-apis-gmail_v1` | Official Gmail REST API client                       |
| `googleauth`           | OAuth 2.0 with automatic token refresh               |
| `net-imap` ~> 0.4      | Yahoo Mail IMAP connection                           |
| `mail` ~> 2.8          | MIME/multipart email parsing                         |
| `ruby_llm` ~> 1.12     | Mistral AI client for email classification           |
| `dotenv` ~> 3.0        | Environment variable loading                         |
| `dry-cli`              | CLI command framework                                |

---

## Security notes

- `credentials.json`, `token.yaml`, and `.env` contain secrets — **do not
  commit them**. They are listed in `.gitignore`.
- Gmail uses the `gmail.modify` scope — read and label modification only; no
  send or delete.
- The MCP server binds to **stdio only** — no network port is opened.
