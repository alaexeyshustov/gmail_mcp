# GitHub Copilot MCP Configuration for Gmail Server

This guide explains how to integrate the Gmail MCP server with GitHub Copilot.

## For JetBrains IDEs (RubyMine, IntelliJ IDEA, etc.)

### Global Configuration

Create or edit: `~/.config/github-copilot/mcp.json`

```json
{
  "mcpServers": {
    "gmail": {
      "command": "ruby",
      "args": ["mcp_server.rb"],
      "cwd": "/Users/aleksey.shustov/gmail_mcp"
    }
  }
}
```

### Project Configuration

Use the `.mcp.json` file in the project root (already included). JetBrains
picks it up automatically when you open the project.

## For VS Code

Add to your VS Code settings (`.vscode/settings.json` or user settings):

```json
{
  "github.copilot.advanced": {
    "mcp": {
      "servers": {
        "gmail": {
          "command": "ruby",
          "args": ["mcp_server.rb"],
          "cwd": "/Users/aleksey.shustov/gmail_mcp"
        }
      }
    }
  }
}
```

## Prerequisites

Before the IDE can connect to the server, the OAuth token must already exist.
Run this once in a terminal so the interactive browser flow can complete:

```bash
cd /Users/aleksey.shustov/gmail_mcp
bin/gmail_mcp setup   # or: ruby mcp_server.rb  (triggers auth on first run)
```

## Testing the Integration

1. Restart your IDE or reload GitHub Copilot
2. Open GitHub Copilot Chat
3. Try these commands:
   - "Show me my 5 most recent emails"
   - "How many unread emails do I have?"
   - "Search for emails from john@example.com"
   - "Find unread emails with attachments"

## Troubleshooting

If Copilot doesn't detect the server:
1. Verify the server runs: `ruby mcp_server.rb`
2. Check the path in `.mcp.json` (or `~/.config/github-copilot/mcp.json`) is correct
3. Make sure `token.yaml` exists (run `bin/gmail_mcp setup` first)
4. Restart your IDE
5. Check GitHub Copilot logs for errors

