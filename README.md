# Gmail MCP Server

A Model Context Protocol (MCP) server for reading emails from Gmail, integrated with GitHub Copilot.

## Features

- **List Recent Emails**: Retrieve the most recent emails from your Gmail inbox
- **Search Emails**: Search emails using Gmail's powerful search syntax
- **Get Specific Email**: Retrieve a specific email by its ID
- **Get Labels**: List all Gmail labels
- **Get Unread Count**: Get the count of unread emails

## Prerequisites

- Ruby 2.7 or higher
- A Google Cloud Project with Gmail API enabled
- OAuth 2.0 credentials from Google Cloud Console

## Setup

### 1. Install Dependencies

```bash
bundle install
```

### 2. Set Up Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Gmail API:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Gmail API"
   - Click "Enable"

### 3. Create OAuth 2.0 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. Choose "Desktop app" as the application type
4. Give it a name (e.g., "Gmail MCP Server")
5. Click "Create"
6. Download the JSON file
7. Save it to `~/.gmail_mcp/credentials.json`

```bash
mkdir -p ~/.gmail_mcp
# Copy your downloaded credentials.json to ~/.gmail_mcp/credentials.json
```

### 4. First Run - Authorization

On the first run, the server will prompt you to authorize access:

```bash
ruby gmail_server.rb
```

Follow these steps:
1. Open the URL displayed in your browser
2. Sign in with your Google account
3. Grant the requested permissions
4. Copy the authorization code
5. Paste it into the terminal

The authorization token will be saved to `~/.gmail_mcp/token.yaml` for future use.

## GitHub Copilot Integration

### For VS Code

Add this to your VS Code settings (`.vscode/settings.json` or user settings):

```json
{
  "github.copilot.advanced": {
    "mcp": {
      "servers": {
        "gmail": {
          "command": "ruby",
          "args": ["gmail_server.rb"],
          "cwd": "/Users/aleksey.shustov/RubymineProjects/gmail_mcp"
        }
      }
    }
  }
}
```

### For JetBrains IDEs (RubyMine, IntelliJ IDEA, etc.)

Create or update the MCP configuration file at `~/.config/github-copilot/mcp.json`:

```json
{
  "mcpServers": {
    "gmail": {
      "command": "ruby",
      "args": ["gmail_server.rb"],
      "cwd": "/Users/aleksey.shustov/RubymineProjects/gmail_mcp"
    }
  }
}
```

Or add it to your project's `.mcp.json` file (already included in this project).

## Available Tools

### 1. list_emails

List recent emails from your Gmail inbox.

**Parameters:**
- `max_results` (optional): Maximum number of emails to retrieve (default: 10, max: 50)

**Example usage in Copilot:**
- "List my 20 most recent emails"
- "Show me my latest emails"

### 2. search_emails

Search emails using Gmail search syntax.

**Parameters:**
- `query` (required): Gmail search query
- `max_results` (optional): Maximum number of emails to retrieve (default: 10, max: 50)

**Search query examples:**
- `from:user@example.com` - Emails from a specific sender
- `subject:meeting` - Emails with "meeting" in the subject
- `is:unread` - Unread emails
- `is:starred` - Starred emails
- `has:attachment` - Emails with attachments
- `after:2024/01/01` - Emails after a specific date
- `label:important` - Emails with a specific label

**Example usage in Copilot:**
- "Search for unread emails from john@example.com"
- "Find emails with subject 'invoice' from last month"

### 3. get_email

Get a specific email by its ID.

**Parameters:**
- `message_id` (required): The Gmail message ID

**Example usage in Copilot:**
- "Get the email with ID 18c2f3e4b5a6789"

### 4. get_labels

List all Gmail labels.

**Example usage in Copilot:**
- "Show me all my Gmail labels"
- "What labels do I have in Gmail?"

### 5. get_unread_count

Get the count of unread emails.

**Example usage in Copilot:**
- "How many unread emails do I have?"
- "What's my unread count?"

## Usage Examples

Once integrated with GitHub Copilot, you can interact with your Gmail using natural language:

1. **Check recent emails:**
   - "Show me my 10 most recent emails"
   - "What are my latest emails?"

2. **Search for specific emails:**
   - "Find all unread emails from alice@example.com"
   - "Search for emails about 'project deadline'"
   - "Show me emails with attachments from this week"

3. **Check email details:**
   - "Get the full content of email [ID]"
   - "Show me the body of the first email"

4. **Check status:**
   - "How many unread emails do I have?"
   - "What Gmail labels do I have?"

## Security Notes

- The server only requests **read-only** access to your Gmail (`AUTH_GMAIL_READONLY` scope)
- Your credentials are stored locally in `~/.gmail_mcp/`
- Never commit `credentials.json` or `token.yaml` to version control
- The `.gitignore` file is configured to exclude these sensitive files

## Troubleshooting

### "Credentials file not found"

Make sure you've downloaded your OAuth 2.0 credentials and saved them to `~/.gmail_mcp/credentials.json`.

### "Authorization failed"

1. Delete the token file: `rm ~/.gmail_mcp/token.yaml`
2. Run the server again and re-authorize

### "API not enabled"

Make sure the Gmail API is enabled in your Google Cloud Console project.

### Connection issues

Ensure your internet connection is stable and you can access Google services.

## Development

### Running the server directly

```bash
ruby gmail_server.rb
```

### Testing

The project includes a comprehensive test suite using RSpec:

```bash
# Run all tests
bundle exec rake spec

# Run specific tests
bundle exec rspec spec/lib/gmail_service_spec.rb

# See TESTING.md for more details
```

**Test Coverage**: 25 examples covering:
- Gmail service unit tests
- MCP tool schema validation
- Response format validation
- Error handling

### Testing individual functions

You can modify the server file to test specific functions or add new tools.

## License

MIT

## Contributing

Feel free to submit issues or pull requests for improvements!

