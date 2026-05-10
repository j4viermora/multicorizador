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

## Skills

When working on this project, use these skills for specialized assistance:

- **`rails-expert`** — Use for Active Record query optimization, Turbo Frames/Streams, Action Cable, Sidekiq/Solid Queue patterns, and Rails 7+ best practices. Reference docs available in `.agents/skills/rails-expert/references/`.
- **`frontend-design`** — Use for building UI components, pages, and layouts with TailwindCSS + DaisyUI. Useful for designing producer/admin dashboards, forms, and public-facing pages.

## Architecture

**Module name:** `Asisto` (defined in [config/application.rb](config/application.rb)), despite the repo directory being `multicorizador`.

**Purpose:** Multi-tenant SaaS platform for travel insurance quotation and comparison. Producers (insurance agents) create quotes that are sent to multiple insurance providers in parallel, results are compared, and policies are issued upon purchase.

### Database

**Engine:** SQLite3 (MVP). Schema is PostgreSQL-compatible for future migration.

**Key tables:** `companies`, `users`, `providers`, `insurance_plans`, `commission_contracts`, `quotes`, `quote_results`, `policies`, `travelers`, `links`, `producer_invoices`, `producer_invoice_policies`, `platform_invoices`.

### Multi-tenancy

Every request is scoped to a `Company` via `acts_as_tenant`. `ApplicationController` sets the tenant from `current_user.company` on every authenticated request and also sets `Money.default_currency` from the company's currency. Super admins operate without tenant (`ActsAsTenant.current_tenant = nil`). Models that are tenant-scoped must call `acts_as_tenant :company`.

### Authentication & Authorization

Devise with `User` belonging to `Company` (optional for super_admins).

**Roles:** `producer` (0), `super_admin` (1) — integer enum.
**Statuses:** `pending` (0), `active` (1), `suspended` (2) — integer enum.

- `super_admin` users access the `/admin` namespace and Mission Control Jobs at `/jobs`.
- `producer` users with `active` status access the `/producer` namespace.
- `pending`/`suspended` producers are signed out and redirected to login.
- `is_superuser` boolean on `User` gates Mission Control Jobs access (legacy, prefer `super_admin?`).

### Route Namespaces

- **`/admin/*`** — Super admin: providers, insurance plans, commission contracts, users, finances, platform invoices, dashboard.
- **`/producer/*`** — Active producers: quotes, travelers, policies, commissions, invoices, dashboard.
- **`/public/quotes/:token`** — Unauthenticated: view/update quotes via public token.
- **`/webhooks/:provider_slug`** — Provider webhook endpoint.

### Business Logic

**Quote lifecycle:** `draft` → `quoting` → `quoted` → `pending_payment` → `purchased` / `cancelled`. Also `client_pending` when shared via link.

**Commission model:** `CommissionContract` stores `provider_commission_rate` (0–1) and `producer_share_rate` (0–1). Platform commission = provider commission − producer commission. Contracts resolve per provider+producer or fall back to provider default (null producer).

**Provider integration:** Service objects in `app/services/insurance_providers/`. `BaseProvider` defines the interface (`quote`, `purchase_url`, `parse_webhook`, `valid_webhook?`). Providers register in `REGISTRY` hash by slug. `ExampleProvider` serves as reference implementation.

### Background Jobs

Solid Queue (DB-backed), started as a separate process in `Procfile.dev`. In production it runs inside Puma via `SOLID_QUEUE_IN_PUMA=true`.

**Jobs:**
- `QuoteJob` — Orchestrates quoting: updates status to `quoting`, enqueues `ProviderQuoteJob` for each active provider.
- `ProviderQuoteJob` — Calls provider API, resolves commission contract, creates `QuoteResult`. Retries 3x on `ProviderError` with 5s backoff.
- `WebhookProcessorJob` — Processes provider webhooks, creates `Policy` records.

### Frontend Stack

Propshaft (assets) + Importmap (JS) + TailwindCSS 4 + DaisyUI + Hotwire (Turbo + Stimulus). No Node/webpack build step — CSS is compiled by `bin/rails tailwindcss:watch`.

**Forms:** `simple_form` gem.
**Search/filter:** `ransack` gem.
**Pagination:** `kaminari` gem.
**Rich text:** `lexxy` gem (not ActionText's Trix).
**Money fields:** `money-rails` gem — monetized fields stored as `_cents`/`_currency` columns.

### Internationalisation

Default locale is `:es`; English (`:en`) is also available. Use `I18n.t()` and locale files under `config/locales/`. UI text is in Spanish, code is in English.

### Email

Resend in production, `letter_opener` in development (emails open in browser). No custom mailers implemented yet — only `ApplicationMailer` base class.

### Deployment

Kamal (`bin/kamal`). Config in [config/deploy.yml](config/deploy.yml). Rails master key is the only required secret (`RAILS_MASTER_KEY`). SQLite database persisted via Docker volume. SSL via Let's Encrypt proxy.
