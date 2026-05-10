# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Start development server (web + TailwindCSS watcher + Solid Queue worker)
bin/dev

# Run all tests
bin/rails test

# Run a single test file
bin/rails test test/models/user_test.rb

# Run a single test by line number
bin/rails test test/models/user_test.rb:42

# Lint
bin/rubocop

# Security scan
bin/brakeman

# Database
bin/rails db:create db:migrate db:seed
```

## Architecture

**Module name:** `Asisto` (defined in [config/application.rb](config/application.rb)), despite the repo directory being `multicorizador`.

**Multi-tenancy:** Every request is scoped to a `Company` via `acts_as_tenant`. `ApplicationController` calls `set_current_tenant(current_user.company)` on every authenticated request and also sets `Money.default_currency` from the company's currency. Models that are tenant-scoped must call `acts_as_tenant :company`.

**Authentication:** Devise with `User` belonging to `Company`. The `is_superuser` boolean on `User` gates access to the Mission Control Jobs UI at `/jobs`.

**Background jobs:** Solid Queue (DB-backed), started as a separate process in `Procfile.dev`. In production it runs inside Puma via `SOLID_QUEUE_IN_PUMA=true`.

**Frontend stack:** Propshaft (assets) + Importmap (JS) + TailwindCSS + DaisyUI + Hotwire (Turbo + Stimulus). No Node/webpack build step — CSS is compiled by `bin/rails tailwindcss:watch`.

**Internationalisation:** Default locale is `:es`; English (`:en`) is also available. Use `I18n.t()` and locale files under `config/locales/`.

**Email:** Resend in production, `letter_opener` in development (emails open in browser).

**Rich text:** `lexxy` gem (not ActionText's Trix).

**Local infrastructure:** PostgreSQL via Docker Compose (`docker-compose up -d`). Credentials: user `asisto`, password `password`, databases `asito_development` / `asisto_test`.

**Deployment:** Kamal (`bin/kamal`). Config in [config/deploy.yml](config/deploy.yml). Rails master key is the only required secret (`RAILS_MASTER_KEY`).
