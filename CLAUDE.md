# CLAUDE.md — Agent Instructions for Mail MCP Server

## Project Overview

This is a **Ruby** MCP (Model Context Protocol) server that exposes Gmail **and** Yahoo Mail as unified tools for AI agents. It uses the `fast-mcp` gem for the MCP server, a provider-adapter pattern (`Adapters::GmailAdapter`, `Adapters::YahooAdapter`) behind a `ProviderRegistry`, and `ruby_llm` for email classification.

The project also includes a **multi-agent job-application tracking pipeline** (`lib/pipeline/`) that runs on top of the MCP server via `ruby_llm-mcp`. The pipeline classifies incoming emails, labels them in Gmail/Yahoo, and maintains two CSV files (`application_mails.csv`, `interviews.csv`) tracking the full application lifecycle.

**Language: Ruby (3.1+). Do NOT use Python anywhere in this project.**

---

## Critical Rules

1. **Always create a plan first** — before writing any code, outline the steps you will take (files to create/modify, classes involved, dependencies).
2. **Always create specs first** — write RSpec tests before implementing any new feature or tool. Tests drive the design.
3. **Never use Python** — this is a pure Ruby project. All code, scripts, and tooling must be Ruby.
4. **Never commit secrets** — `credentials.json`, `token.yaml`, and `.env` are git-ignored. Do not create or modify them.
5. **Always keep CLAUDE.md current** — update it whenever files, tools, commands, or architecture change.

---

## Project Structure

```
mail_mcp/
├── bin/cli                          # Dry::CLI entry point (setup, test, reset, status, server, jobs_pipeline)
├── application_mails.csv            # Tracks job application emails (date, provider, email_id, company, job_title, action)
├── interviews.csv                   # Tracks interview lifecycle per company/job_title
├── lib/
│   ├── loader.rb                    # Zeitwerk autoloader setup — require this file to load everything under lib/
│   ├── mcp_server.rb                # MCP server entry point — boots both adapters, registers tools
│   ├── provider_registry.rb         # { "gmail" => GmailAdapter, "yahoo" => YahooAdapter }
│   ├── email_classifier.rb          # Mistral-based email classification via ruby_llm
│   ├── adapters/
│   │   ├── base_adapter.rb          # Abstract interface all adapters must implement
│   │   ├── gmail_adapter.rb         # Wraps GmailService, conforms to base interface
│   │   └── yahoo_adapter.rb         # Wraps YahooMailService, conforms to base interface
│   ├── pipeline/                    # Multi-agent job-tracking pipeline (runs on top of the MCP server)
│   │   ├── jobs_workflow.rb          # 5-step sequential workflow orchestrator
│   │   ├── logger.rb                # Centralised pipeline logger (wraps Ruby Logger, levels: debug/info/warn/error)
│   │   ├── mcp_connection.rb        # Lifecycle wrapper for RubyLLM::MCP::Client (stdio)
│   │   └── agents/
│   │       ├── init_database_agent.rb          # Step 1: reads application_mails.csv, returns cutoff + known IDs
│   │       ├── email_fetch_agent.rb             # Step 2: fetches emails since cutoff (paginates at 100)
│   │       ├── classify_and_filter_agent.rb     # Step 3: classifies & keeps only job-related emails
│   │       ├── label_and_store_agent.rb         # Step 4: labels emails in provider, appends rows to CSV
│   │       └── reconcile_interviews_agent.rb    # Step 5: syncs interviews.csv with new application rows
│   ├── services/
│   │   ├── gmail_service.rb         # Gmail API wrapper (OAuth, list, get, search, modify labels)
│   │   ├── gmail_auth.rb            # Google OAuth2 loopback flow (browser → localhost callback)
│   │   ├── gist_uploader.rb         # Uploads CSV files to GitHub Gist via REST API
│   │   └── yahoo_mail_service.rb    # Yahoo IMAP wrapper (Net::IMAP)
│   └── tools/                       # One file per MCP tool — each accepts a `provider:` argument (except manage_csv)
│       ├── list_emails.rb
│       ├── get_email.rb
│       ├── search_emails.rb
│       ├── get_labels.rb            # Returns Gmail labels or Yahoo folders (unified shape)
│       ├── get_unread_count.rb
│       ├── add_labels.rb            # Gmail: label IDs; Yahoo: IMAP flags
│       ├── classify_emails.rb       # Provider-agnostic (works on subject lines)
│       └── manage_csv.rb            # Provider-agnostic CSV CRUD (read, create, add_rows, add_columns, update_rows)
├── spec/
│   ├── spec_helper.rb               # RSpec config + WebMock + VCR
│   ├── support/
│   │   ├── fake_mcp_tool.rb         # Stub MCP tool for pipeline/agent specs
│   │   ├── gmail_fixtures.rb        # Gmail shared test doubles & helpers
│   │   └── yahoo_mail_fixtures.rb   # Yahoo shared test doubles & helpers
│   └── lib/
│       ├── adapters/
│       │   ├── base_adapter_spec.rb
│       │   ├── gmail_adapter_spec.rb
│       │   └── yahoo_adapter_spec.rb
│       ├── services/
│       │   ├── gmail_service_spec.rb
│       │   ├── gist_uploader_spec.rb
│       │   └── yahoo_mail_service_spec.rb
│       ├── pipeline/
│       │   ├── agent_spec.rb
│       │   ├── jobs_workflow_spec.rb
│       │   ├── logger_spec.rb
│       │   └── agents/
│       │       ├── classify_and_filter_agent_spec.rb
│       │       ├── email_fetch_agent_spec.rb
│       │       ├── init_database_agent_spec.rb
│       │       ├── label_and_store_agent_spec.rb
│       │       └── reconcile_interviews_agent_spec.rb
│       ├── provider_registry_spec.rb
│       ├── email_classifier_spec.rb
│       ├── gmail_auth_spec.rb
│       └── tools/                   # One spec per tool — tests both gmail and yahoo providers where applicable
│           ├── list_emails_spec.rb
│           ├── get_email_spec.rb
│           ├── search_emails_spec.rb
│           ├── get_labels_spec.rb
│           ├── get_unread_count_spec.rb
│           ├── add_labels_spec.rb
│           ├── classify_emails_spec.rb
│           └── manage_csv_spec.rb
├── Gemfile
├── .env.example                     # Environment variable template (Gmail + Yahoo + Pipeline)
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
| CLI start server       | `bin/cli server`                                                                |
| Run pipeline once      | `bin/cli jobs_pipeline`                                                         |
| Run pipeline (watch)   | `bin/cli jobs_pipeline --watch`                                                 |
| Run pipeline (model)   | `bin/cli jobs_pipeline --model gpt-5.1`                                         |
| Run pipeline (debug)   | `bin/cli jobs_pipeline --log-level debug`                                       |

---

## Architecture Notes

- **Autoloading**: The project uses [Zeitwerk](https://github.com/fxn/zeitwerk) for autoloading. `lib/loader.rb` creates a single `Zeitwerk::Loader` instance pointed at `lib/`. `lib/services/` is _collapsed_ so its files define top-level constants (`GmailService`, `GmailAuth`, `YahooMailService`) rather than `Services::*`. `lib/loader.rb` and `lib/mcp_server.rb` are ignored by the loader. Every entry-point (`lib/mcp_server.rb`, `bin/cli`, `spec/spec_helper.rb`) loads `lib/loader.rb`; no individual `require_relative` for project files is needed elsewhere.
- **Provider adapter pattern**: Tools call `self.class.registry.fetch(provider)` to get the right adapter (`GmailAdapter` or `YahooAdapter`). Adapters inherit from `Adapters::BaseAdapter` and wrap the underlying services.
- **ProviderRegistry**: Holds a name → adapter hash. Adapters are registered only when credentials are present (Gmail: `credentials.json`; Yahoo: `YAHOO_USERNAME` + `YAHOO_APP_PASSWORD`).
- **Dependency injection**: Tools receive the registry through a class-level accessor (`registry=`), set in `mcp_server.rb`. The classifier uses a separate `classifier=` accessor.
- **Single service instances**: `GmailService` and `YahooMailService` are created once in `mcp_server.rb` and shared across their respective adapters.
- **Tool `provider` argument**: Every tool (except `classify_emails` and `manage_csv`) requires `provider: "gmail"` or `provider: "yahoo"`. Unsupported providers raise `ProviderRegistry::UnknownProviderError`.
- **OAuth scope** (Gmail): `gmail.modify` — read and label modification, no send/delete.
- **IMAP connection** (Yahoo): persistent `Net::IMAP` connection with mutex + auto-reconnect; `at_exit` calls `disconnect`.
- **MCP transport**: stdio only (stdin/stdout JSON-RPC). No HTTP server.
- **Environment variables**: Loaded via `dotenv`. See `.env.example`.

### Pipeline Architecture

- **`Pipeline::Logger`**: Centralised logger for all pipeline activity. Wraps Ruby's `Logger` with a fixed `[Pipeline] [SEVERITY] message` format. Levels: `:debug` (verbose detail), `:info` (step banners, default), `:warn`, `:error`. Constructed once in `bin/cli` and injected into `JobsWorkflow`.
- **`Pipeline::McpConnection`**: Wraps `RubyLLM::MCP::Client` (stdio transport). Spawns `lib/mcp_server.rb` as a subprocess, exposes `tools` for injection into agents, and provides a `stop` method for cleanup.
- **`Pipeline::JobsWorkflow`**: Orchestrates the 5-step sequential pipeline. Each step creates a fresh `RubyLLM::Agent`, injects only the MCP tools listed in the agent's `TOOLS` constant, runs the agent with a structured message, then passes the result to the next step. Ruby code handles all inter-step data transformation. Accepts an optional `logger:` kwarg (defaults to `Pipeline::Logger.new`).
- **Agent design**: Each agent is a `RubyLLM::Agent` subclass with a `TOOLS` constant (list of MCP tool names), a default `model` (`mistral-large-latest`), and a `instructions` block. The workflow can override the model at runtime via `--model`.
- **`GistUploader`**: Uploads a local CSV file to a GitHub Gist (create or update). Reads `GITHUB_TOKEN` and optionally `GIST_ID` from env. Used to share `interviews.csv` externally. Lives in `lib/services/` (Zeitwerk-collapsed, so top-level constant).
- **`BATCH_SIZE = 15`**: LabelAndStoreAgent processes job emails in batches of 15 to stay within LLM context limits.
- **Workflow env vars**: `APPLICATION_CSV_PATH`, `INTERVIEWS_CSV_PATH`, `LOOKBACK_MONTHS` (default 3), `MCP_TIMEOUT_SECONDS` (default 120), `MISTRAL_API_KEY`, `GITHUB_TOKEN`, `GIST_ID`.

---

## How to Add a New MCP Tool

### Step 1: Plan

Before writing code, outline:

- Tool name and description
- Required and optional arguments with types (include `provider:` as required unless the tool is provider-agnostic like `manage_csv` or `classify_emails`)
- Which adapter method(s) the tool will call
- Whether `BaseAdapter` / adapters need new methods
- Edge cases and error scenarios

### Step 2: Write the spec first

Create `spec/lib/tools/<tool_name>_spec.rb` following the pattern below. Test both providers. Zeitwerk is set up in `spec_helper` — only require `spec_helper`; do **not** add individual `require_relative` for lib files.

```ruby
require_relative '../../spec_helper'

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

For provider-agnostic tools (no `provider:` argument, like `manage_csv`), omit the provider-related contexts and test the tool's logic directly.

### Step 3: Implement the tool

Create `lib/tools/<tool_name>.rb` following the existing pattern. Zeitwerk autoloads all project files — do **not** add `require_relative` for project constants; only `require` external gems.

```ruby
require 'fast_mcp'

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

For provider-agnostic tools, omit `provider:` from arguments and implement the logic directly in `call`.

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


### Step 5: Run formatter rubyfmt

```bash
rubyfmt 
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
- **Never use double() and instance_double() in specs** - always use method spies or VCR casettes.
- **Never test fot method_defined? or respond_to** - always call a method and test the output.

---

## VCR Cassette Conventions

Cassettes live in `spec/cassettes/` under topic-named subdirectories:

- `spec/cassettes/gmail_service/` — Gmail API calls in `GmailService`
- `spec/cassettes/email_classifier/` — LLM calls in `EmailClassifier`
- `spec/cassettes/workflow/` — end-to-end pipeline workflow scenarios

---

## Workflow Checklist (for every change)

1. [ ] Create a plan — list files to change and why
2. [ ] Write or update specs first
3. [ ] Run the new specs — confirm they fail for the right reason
4. [ ] Implement the change
5. [ ] Run `bundle exec rspec` — all specs must pass
6. [ ] Update `mcp_server.rb` registration if adding a tool
7. [ ] Do not modify `credentials.json`, `token.yaml`, or `.env`
