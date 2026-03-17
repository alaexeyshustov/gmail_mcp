# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ruby MCP (Model Context Protocol) server exposing Gmail and Yahoo Mail as unified tools for AI agents. Uses `fast-mcp` for the MCP layer, a provider-adapter pattern behind `ProviderRegistry`, and `ruby_llm` for email classification.

**Language: Ruby (3.1+). Do NOT use Python anywhere.**

---

## Critical Rules

1. **Always create a plan first** — outline files to change and why before writing any code.
2. **Always write specs first** — RSpec tests drive the design.
3. **Never commit secrets** — `credentials.json`, `token.yaml`, and `.env` are git-ignored.
4. **Always keep CLAUDE.md current** — update it when files, tools, or architecture change.

---

## Commands

| Task                   | Command                                                                         |
| ---------------------- | ------------------------------------------------------------------------------- |
| Install dependencies   | `bundle install`                                                                |
| Run all tests          | `bundle exec rspec`                                                             |
| Run a single spec file | `bundle exec rspec spec/lib/tools/list_emails_spec.rb`                          |
| Run a specific test    | `bundle exec rspec spec/lib/tools/list_emails_spec.rb -e "calls list_messages"` |
| Format code            | `rubyfmt`                                                                       |
| Start MCP server       | `bundle exec ruby lib/mcp_server.rb`                                            |
| CLI setup              | `bin/cli setup`                                                                 |
| CLI test (live Gmail)  | `bin/cli test`                                                                  |
| CLI status             | `bin/cli status`                                                                |
| CLI reset auth         | `bin/cli reset`                                                                 |
| CLI start server       | `bin/cli server`                                                                |                 |
                                |

---

## Architecture

### Core

- **Autoloading**: Zeitwerk via `lib/loader.rb`. `lib/services/` is _collapsed_ so files define top-level constants (`GmailService`, `GmailAuth`, `YahooMailService`). Every entry-point loads `lib/loader.rb`; no `require_relative` for project files needed elsewhere.
- **Provider adapter pattern**: Tools call `self.class.registry.fetch(provider)` → `GmailAdapter` or `YahooAdapter`, both inheriting `Adapters::BaseAdapter`. Adapters are registered only when credentials are present.
- **Dependency injection**: Tools receive the registry via `registry=` class accessor set in `mcp_server.rb`. `classify_emails` uses a separate `classifier=` accessor.
- **Tool `provider` argument**: All tools except `classify_emails` and `manage_csv` require `provider: "gmail"` or `provider: "yahoo"`. Unsupported providers raise `ProviderRegistry::UnknownProviderError`.
- **MCP transport**: stdio only (stdin/stdout JSON-RPC). The `.mcp.json` at project root configures IDEs (VS Code, JetBrains) to launch the server automatically via `bin/cli server`.


## Adding a New MCP Tool

1. Plan: tool name, arguments (include `provider:` unless provider-agnostic), adapter methods needed, edge cases.
2. Create `spec/lib/tools/<tool_name>_spec.rb` — test `provider: 'gmail'`, `provider: 'yahoo'`, unknown provider raises `UnknownProviderError`, and `.tool_name`.
3. Create `lib/tools/<tool_name>.rb` — subclass `FastMcp::Tool`, define `tool_name`, `description`, `arguments`, `call`, and `class << self; attr_accessor :registry; end`.
4. Register in `lib/mcp_server.rb`: add `require_relative` and add to `ALL_TOOLS`.
5. Run `bundle exec rspec`.

See any existing tool in `lib/tools/` for the exact pattern.

## Adding a New Adapter Method

1. Add abstract method to `lib/adapters/base_adapter.rb` (raises `NotImplementedError`).
2. Write specs in both `gmail_adapter_spec.rb` and `yahoo_adapter_spec.rb`.
3. Implement in `GmailAdapter` (delegate to `GmailService`) and `YahooAdapter` (delegate to `YahooMailService`).

## Adding a New GmailService Method

1. Write spec in `spec/lib/services/gmail_service_spec.rb` using `VCR.use_cassette`. Create cassette YAML in `spec/cassettes/gmail_service/`.
2. Implement in `lib/services/gmail_service.rb`. Always return plain Ruby hashes/arrays, not Google API objects.

---

## Testing Conventions

- **HTTP mocking**: WebMock blocks all real HTTP. `config.disable_monkey_patching!` is on.
- **Test doubles**: Use method spies (`allow(...).to receive(...)`) or VCR cassettes. Do **not** use `double()` or `instance_double()`.
- **Never test `method_defined?` or `respond_to?`** — call the method and test the output.
- **Fixtures**: Shared helpers in `spec/support/gmail_fixtures.rb` and `spec/support/yahoo_mail_fixtures.rb`.
- **VCR cassettes**: `spec/cassettes/gmail_service/`, `spec/cassettes/email_classifier/`, `spec/cassettes/workflow/`.

---

## Workflow Checklist

1. [ ] Plan — list files to change and why
2. [ ] Write specs first; confirm they fail for the right reason
3. [ ] Implement
4. [ ] `bundle exec rspec` — full suite must pass
5. [ ] `rubyfmt` — format changed files
6. [ ] Update `mcp_server.rb` registration if adding a tool
7. [ ] Update CLAUDE.md if architecture changed
