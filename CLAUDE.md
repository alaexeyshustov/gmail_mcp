# CLAUDE.md — Agent Instructions for Mail MCP Server

## Project Overview

This is a **Ruby** MCP (Model Context Protocol) server that exposes Gmail **and** Yahoo Mail as unified tools for AI agents. It uses the `fast-mcp` gem for the MCP server, a provider-adapter pattern (`Adapters::GmailAdapter`, `Adapters::YahooAdapter`) behind a `ProviderRegistry`, and `ruby_llm` for email classification.

**Language: Ruby (3.1+). Do NOT use Python anywhere in this project.**

---

## Critical Rules

1. **Always create a plan first** — before writing any code, outline the steps you will take (files to create/modify, classes involved, dependencies).
2. **Always create specs first** — write RSpec tests before implementing any new feature or tool. Tests drive the design.
3. **Never use Python** — this is a pure Ruby project. All code, scripts, and tooling must be Ruby.
4. **Never commit secrets** — `credentials.json`, `token.yaml`, and `.env` are git-ignored. Do not create or modify them.

---

## Project Structure

```
mail_mcp/
├── bin/cli                          # Dry::CLI entry point (setup, test, reset, status, server)
├── lib/
│   ├── mcp_server.rb                # MCP server entry point — boots both adapters, registers tools
│   ├── provider_registry.rb         # { "gmail" => GmailAdapter, "yahoo" => YahooAdapter }
│   ├── email_classifier.rb          # Mistral-based email classification via ruby_llm
│   ├── adapters/
│   │   ├── base_adapter.rb          # Abstract interface all adapters must implement
│   │   ├── gmail_adapter.rb         # Wraps GmailService, conforms to base interface
│   │   └── yahoo_adapter.rb         # Wraps YahooMailService, conforms to base interface
│   ├── services/
│   │   ├── gmail_service.rb         # Gmail API wrapper (OAuth, list, get, search, modify labels)
│   │   ├── gmail_auth.rb            # Google OAuth2 loopback flow (browser → localhost callback)
│   │   └── yahoo_mail_service.rb    # Yahoo IMAP wrapper (Net::IMAP)
│   └── tools/                       # One file per MCP tool — each accepts a `provider:` argument
│       ├── list_emails.rb
│       ├── get_email.rb
│       ├── search_emails.rb
│       ├── get_labels.rb            # Returns Gmail labels or Yahoo folders (unified shape)
│       ├── get_unread_count.rb
│       ├── add_labels.rb            # Gmail: label IDs; Yahoo: IMAP flags
│       └── classify_emails.rb       # Provider-agnostic (works on subject lines)
├── spec/
│   ├── spec_helper.rb               # RSpec config + WebMock + VCR
│   ├── support/
│   │   ├── gmail_fixtures.rb        # Gmail shared test doubles & helpers
│   │   └── yahoo_mail_fixtures.rb   # Yahoo shared test doubles & helpers
│   └── lib/
│       ├── adapters/
│       │   ├── base_adapter_spec.rb
│       │   ├── gmail_adapter_spec.rb
│       │   └── yahoo_adapter_spec.rb
│       ├── services/
│       │   ├── gmail_service_spec.rb
│       │   └── yahoo_mail_service_spec.rb
│       ├── provider_registry_spec.rb
│       ├── email_classifier_spec.rb
│       ├── gmail_auth_spec.rb
│       └── tools/                   # One spec per tool — tests both gmail and yahoo providers
│           ├── list_emails_spec.rb
│           ├── get_email_spec.rb
│           ├── search_emails_spec.rb
│           ├── get_labels_spec.rb
│           ├── get_unread_count_spec.rb
│           ├── add_labels_spec.rb
│           └── classify_emails_spec.rb
├── Gemfile
├── .env.example                     # Environment variable template (Gmail + Yahoo)
└── credentials.json.example         # OAuth credentials template
```

---

## Commands

| Task                   | Command                                                                         |
| ---------------------- | ------------------------------------------------------------------------------- |
| Install dependencies   | `bundle install`                                                                |
| Run all tests          | `bundle exec rspec`                                                             |
| Run a single spec file | `bundle exec rspec spec/lib/tools/list_emails_spec.rb`                          |
| Run a specific test    | `bundle exec rspec spec/lib/tools/list_emails_spec.rb -e "calls list_messages"` |
| Start MCP server       | `bundle exec ruby lib/mcp_server.rb`                                            |
| CLI setup              | `bin/cli setup`                                                                 |
| CLI test (live Gmail)  | `bin/cli test`                                                                  |
| CLI status             | `bin/cli status`                                                                |
| CLI reset auth         | `bin/cli reset`                                                                 |

---

## Architecture Notes

- **Provider adapter pattern**: Tools call `self.class.registry.fetch(provider)` to get the right adapter (`GmailAdapter` or `YahooAdapter`). Adapters inherit from `Adapters::BaseAdapter` and wrap the underlying services.
- **ProviderRegistry**: Holds a name → adapter hash. Adapters are registered only when credentials are present (Gmail: `credentials.json`; Yahoo: `YAHOO_USERNAME` + `YAHOO_APP_PASSWORD`).
- **Dependency injection**: Tools receive the registry through a class-level accessor (`registry=`), set in `mcp_server.rb`. The classifier uses a separate `classifier=` accessor.
- **Single service instances**: `GmailService` and `YahooMailService` are created once in `mcp_server.rb` and shared across their respective adapters.
- **Tool `provider` argument**: Every tool (except `classify_emails`) requires `provider: "gmail"` or `provider: "yahoo"`. Unsupported providers raise `ProviderRegistry::UnknownProviderError`.
- **OAuth scope** (Gmail): `gmail.modify` — read and label modification, no send/delete.
- **IMAP connection** (Yahoo): persistent `Net::IMAP` connection with mutex + auto-reconnect; `at_exit` calls `disconnect`.
- **MCP transport**: stdio only (stdin/stdout JSON-RPC). No HTTP server.
- **Environment variables**: Loaded via `dotenv`. See `.env.example`.

---

## How to Add a New MCP Tool

### Step 1: Plan

Before writing code, outline:

- Tool name and description
- Required and optional arguments with types (always include `provider:` as required)
- Which adapter method(s) the tool will call
- Whether `BaseAdapter` / adapters need new methods
- Edge cases and error scenarios

### Step 2: Write the spec first

Create `spec/lib/tools/<tool_name>_spec.rb` following the pattern below. Test both providers:

```ruby
require_relative '../../spec_helper'
require_relative '../../../lib/provider_registry'
require_relative '../../../lib/tools/<tool_name>'

RSpec.describe Tools::<ToolClass> do
  let(:gmail_adapter) { double('GmailAdapter') }
  let(:yahoo_adapter) { double('YahooAdapter') }
  let(:registry) do
    r = ProviderRegistry.new
    r.register('gmail', gmail_adapter)
    r.register('yahoo', yahoo_adapter)
    r
  end

  before { described_class.registry = registry }

  describe '#call' do
    context 'with provider: "gmail"' do
      it 'calls the expected adapter method' do
        expect(gmail_adapter).to receive(:<method>).with(<args>).and_return(<result>)
        expect(described_class.new.call(provider: 'gmail', <args>)).to eq(<result>)
      end
    end

    context 'with provider: "yahoo"' do
      it 'delegates to the yahoo adapter' do
        expect(yahoo_adapter).to receive(:<method>).and_return(<result>)
        described_class.new.call(provider: 'yahoo', <args>)
      end
    end

    context 'with an unknown provider' do
      it 'raises ProviderRegistry::UnknownProviderError' do
        expect { described_class.new.call(provider: 'invalid', <required_args>) }
          .to raise_error(ProviderRegistry::UnknownProviderError)
      end
    end
  end

  describe '.tool_name' do
    it 'is "<tool_name>"' do
      expect(described_class.tool_name).to eq('<tool_name>')
    end
  end
end
```

### Step 3: Implement the tool

Create `lib/tools/<tool_name>.rb` following the existing pattern:

```ruby
require 'fast_mcp'
require_relative '../provider_registry'

module Tools
  class <ToolClass> < FastMcp::Tool
    tool_name '<tool_name>'
    description '<Human-readable description for LLM agents>'

    arguments do
      required(:provider).filled(:string).description('Email provider: "gmail" or "yahoo"')
      required(:<arg>).filled(:string).description('<description>')
      optional(:<arg>).filled(:integer).description('<description>')
    end

    def call(provider:, <keyword_args>)
      self.class.registry.fetch(provider).<adapter_method>(<args>)
    end

    class << self
      attr_accessor :registry
    end
  end
end
```

### Step 4: Register the tool

In `lib/mcp_server.rb`:

1. Add `require_relative 'tools/<tool_name>'` at the top
2. Add `Tools::<ToolClass>` to the `ALL_TOOLS` constant
3. (The registry injection loop handles the rest automatically)

### Step 5: Run specs

```bash
bundle exec rspec spec/lib/tools/<tool_name>_spec.rb
bundle exec rspec  # full suite — must stay green
```

---

## How to Add a New Adapter Method

### Step 1: Plan

Outline the underlying service call, parameters, and return shape.

### Step 2: Add to BaseAdapter

Add an `abstract` method to `lib/adapters/base_adapter.rb` that raises `NotImplementedError`.

### Step 3: Write specs first

Add tests to both `spec/lib/adapters/gmail_adapter_spec.rb` and `spec/lib/adapters/yahoo_adapter_spec.rb`.

### Step 4: Implement in both adapters

- `lib/adapters/gmail_adapter.rb` — delegate to `GmailService`
- `lib/adapters/yahoo_adapter.rb` — delegate to `YahooMailService` (mapping Yahoo-specific concepts as needed)

### Step 5: Run specs

```bash
bundle exec rspec spec/lib/adapters/
```

---

## How to Add a New GmailService Method

### Step 1: Plan

Outline the Gmail API call, parameters, and return shape.

### Step 2: Write the spec first

Add tests to `spec/lib/services/gmail_service_spec.rb` using `VCR.use_cassette`. Create the cassette YAML file in `spec/cassettes/gmail_service/`.

### Step 3: Implement

Add the method to `lib/services/gmail_service.rb`. Always return plain Ruby hashes/arrays, not Google API objects.

### Step 4: Run specs

```bash
bundle exec rspec spec/lib/services/gmail_service_spec.rb
```

---

## Testing Conventions

- **Framework**: RSpec with `--format documentation`
- **HTTP mocking**: WebMock is enabled globally — all real HTTP is blocked in tests
- **Test doubles**:
  - Tool specs: `double('GmailAdapter')` / `double('YahooAdapter')` + real `ProviderRegistry`
  - Adapter specs: `instance_double(GmailService)` / `instance_double(YahooMailService)`
  - Service specs: VCR cassettes (Gmail) or `instance_double(Net::IMAP)` (Yahoo)
- **Fixtures**: `spec/support/gmail_fixtures.rb` and `spec/support/yahoo_mail_fixtures.rb`
- **No monkey patching**: `config.disable_monkey_patching!` is on
- **File naming**: Spec files mirror `lib/` structure under `spec/lib/`
- **Tool specs always test**: `#call` with `provider: 'gmail'`, `#call` with `provider: 'yahoo'`, unknown provider raises error, `.tool_name`

---

## VCR Cassette Conventions

_(Unchanged — see original conventions. Cassettes live in `spec/cassettes/gmail_service/` and `spec/cassettes/email_classifier/`.)_

---

## Workflow Checklist (for every change)

1. [ ] Create a plan — list files to change and why
2. [ ] Write or update specs first
3. [ ] Run the new specs — confirm they fail for the right reason
4. [ ] Implement the change
5. [ ] Run `bundle exec rspec` — all specs must pass
6. [ ] Update `mcp_server.rb` registration if adding a tool
7. [ ] Do not modify `credentials.json`, `token.yaml`, or `.env`
