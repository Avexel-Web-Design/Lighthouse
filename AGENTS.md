# AGENTS.md — Lighthouse

FRC scouting app built with Ruby on Rails 8.1, PostgreSQL, Hotwire (Turbo + Stimulus), and Tailwind CSS.

## Build & Run Commands

```bash
# Setup (install gems, prepare DB, etc.)
bin/setup

# Start dev server (Rails + Tailwind watcher)
bin/dev

# Run full local CI pipeline (lint, audit, security, tests, seeds)
bin/ci
```

## Test Commands

The test framework is **Minitest** (Rails default). Tests run in parallel.

```bash
# Run entire test suite
bin/rails test

# Run a single test file
bin/rails test test/models/scouting_entry_test.rb

# Run a single test by line number
bin/rails test test/models/scouting_entry_test.rb:106

# Run a single test by name pattern
bin/rails test -n "test_total_fuel_made_for_entry_qm1_254"

# Run all model tests
bin/rails test test/models/

# Run all controller tests
bin/rails test test/controllers/

# Run all service tests
bin/rails test test/services/

# Run system tests (Capybara + Selenium)
bin/rails test:system

# Prepare test database (run after migrations)
bin/rails db:test:prepare
```

## Lint & Security Commands

```bash
# RuboCop (rubocop-rails-omakase style)
bin/rubocop

# RuboCop with auto-correct
bin/rubocop -a

# Security: static analysis
bin/brakeman --quiet --no-pager

# Security: gem vulnerability audit
bin/bundler-audit

# Security: JS dependency audit
bin/importmap audit
```

## Project Structure

```
app/
  controllers/          # RESTful controllers + API namespace (api/v1/)
    concerns/           # ApiAuthenticatable
  models/               # ActiveRecord models (21)
    concerns/           # Scoring module
  services/             # Plain Ruby service objects (9)
  policies/             # Pundit authorization policies (14)
  jobs/                 # ActiveJob background jobs
  javascript/           # Stimulus controllers (ESM via importmap)
  views/                # ERB templates with Tailwind CSS
config/
  importmap.rb          # JS dependency pinning (no npm/node)
  routes.rb             # Route definitions
test/
  models/               # Model unit tests
  controllers/          # Controller integration tests
  services/             # Service object tests
  fixtures/             # YAML fixture data
  test_helper.rb        # Custom helpers, materialized view setup
```

## Code Style Guidelines

### Ruby Style

RuboCop with **rubocop-rails-omakase** (the Rails team's official style guide). No custom overrides. Key rules:
- 2-space indentation
- Double quotes for strings
- Trailing commas not required
- `frozen_string_literal` comment is not enforced
- Follow standard Ruby naming: `snake_case` for methods/variables, `PascalCase` for classes/modules, `SCREAMING_SNAKE_CASE` for constants

### Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Model | Singular, PascalCase | `ScoutingEntry`, `FrcTeam` |
| Controller | Plural + `Controller` | `ScoutingEntriesController` |
| Service | Descriptive + `Service`/`Client` | `AggregationService`, `TbaClient` |
| Policy | Model + `Policy` | `ScoutingEntryPolicy` |
| Job | Action + `Job` | `RefreshSummariesJob` |
| DB tables | snake_case, plural | `scouting_entries`, `frc_teams` |

### Imports & Autoloading

- Rails uses **Zeitwerk** autoloading. Do NOT add `require` statements for app code.
- Test files must start with `require "test_helper"`.
- JavaScript uses **importmap** (no npm/node/bundler). Pin dependencies in `config/importmap.rb`.

### Controller Patterns

- Inherit from `ApplicationController` (or `ActionController::API` for API endpoints).
- Use **Pundit** for authorization: call `authorize @record` in every action.
- Use `before_action :require_event!` on controllers that need a selected event.
- Use `before_action :set_xxx` for resource lookup, scoped to `only:` relevant actions.
- Strong parameters via private `xxx_params` methods.
- Flash messages: `notice:` for success, `alert:` for errors.
- Render `:new`/`:edit` with `status: :unprocessable_entity` on validation failure.
- Use `redirect_to` with `status: :see_other` for destroy actions.

### Model Patterns

- Inherit from `ApplicationRecord`.
- Organize sections with comments: `# Associations`, `# Validations`, `# Scopes`, `# Callbacks`.
- Define enums as: `enum :status, { submitted: 0, flagged: 1, rejected: 2 }`.
- JSONB columns (`data`, `config`, `settings`) are used heavily for flexible scouting data.
- Scopes use lambda syntax: `scope :name, -> { ... }`.

### Service Object Patterns

- Plain Ruby classes — no base class or framework.
- Constructor injection: `def initialize(event)`.
- Use bang methods (`!`) for operations that mutate data or may raise.
- Rescue exceptions, log with `Rails.logger.warn`/`.error`, return `nil` on failure.
- No custom exception classes; rescue `StandardError`, `ActiveRecord::RecordInvalid`, or `Faraday::Error`.

### Test Patterns

- **Minitest** with `ActiveSupport::TestCase` (models/services) and `ActionDispatch::IntegrationTest` (controllers).
- Use descriptive string names: `test "descriptive name" do ... end`.
- Access fixtures by name: `users(:admin_user)`, `events(:championship)`.
- Use `sign_in_as(user)` to authenticate in controller tests.
- Use `select_event(event)` to set the current event in session.
- Common assertions: `assert`, `assert_equal`, `assert_not`, `assert_includes`, `assert_response`, `assert_redirected_to`, `assert_difference`, `assert_no_difference`.
- Group tests with comment headers: `# --- Validations ---`, `# --- Associations ---`.
- All fixtures are loaded globally (`fixtures :all` in test_helper).

### Error Handling

- Controllers: `rescue StandardError => e`, redirect with `alert:` message.
- Services/API clients: rescue specific errors, log, return `nil` or empty.
- No custom exception hierarchy — use standard Ruby/Rails exceptions.

### Authorization (Pundit)

- `ApplicationPolicy` defaults all actions to `false` (deny by default).
- Policies check roles via helpers: `admin?`, `analyst?`, `scout?` (entry policies use a local `owner?` meaning the record's author, not a role).
- Role hierarchy: `scout < analyst < admin` (`User` enum; the old Membership-based `lead`/`owner` roles were removed).
- Every controller action must call `authorize`.

### Frontend

- **Hotwire**: Turbo Frames/Streams for dynamic updates, Stimulus for JS behavior.
- **Tailwind CSS** for styling (no custom CSS framework).
- Turbo Stream broadcasts from controllers and model callbacks for real-time updates.
- Stimulus controllers live in `app/javascript/controllers/`.

### Database

- PostgreSQL with JSONB columns and GIN indexes for flexible scouting data.
- Materialized view `team_event_summaries` for pre-computed aggregations (refreshed via `RefreshSummariesJob`).
- `client_uuid` columns for offline/sync deduplication.

## CI Pipeline

GitHub Actions runs on push to `master` and all PRs:
1. **scan_ruby** — Brakeman + bundler-audit
2. **scan_js** — importmap audit
3. **lint** — RuboCop
4. **test** — `bin/rails db:test:prepare test` (PostgreSQL service)
5. **system-test** — `bin/rails db:test:prepare test:system`
