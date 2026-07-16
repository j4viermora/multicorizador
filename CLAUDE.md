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

# Create super admin
bin/rails admin:create EMAIL=admin@example.com PASSWORD=secret
```

## Local Setup Gotchas

### `bin/dev` fails with `Could not find table 'solid_queue_processes'`

Solid Queue runs on a **separate database** (`storage/development_queue.sqlite3`, see [config/database.yml](config/database.yml)), which uses `db/queue_schema.rb` — **not** the regular migration pipeline. If that file exists but is empty (e.g. after cloning, or the queue DB was created without the schema), `db:migrate` reports success but the worker still crashes because the tables are missing.

Fix when it happens:

```bash
bin/rails solid_queue:install      # (re)generates db/queue_schema.rb if missing
rm -f storage/development_queue.sqlite3   # nuke the empty queue DB
bin/rails db:prepare               # recreates it from db/queue_schema.rb
```

### `css: bin/rails tailwindcss:watch` exits immediately and tears down `bin/dev`

Without a TTY (terminals spawned by some editors, Docker without `tty: true`, CI), the Tailwind CLI exits as soon as `stdin` closes. The `css` process compiles once and exits, which makes Foreman/overmind SIGTERM **all** other processes (web + worker), so `bin/dev` looks like it crashes right after boot.

`Procfile.dev` is already pinned to `bin/rails tailwindcss:watch[always]` to keep the watcher alive. **Do not revert it to the bare `tailwindcss:watch`** — it will break non-TTY environments again.

> TODO (when we move to a real DB / Postgres): The Solid Queue schema lives in `db/queue_schema.rb` because of the multi-DB SQLite setup. On Postgres we must decide whether the queue shares the primary DB or gets its own, and replace this install/prepare dance with proper migrations under `db/queue_migrate` (already wired as the `migrations_paths`). Revisit the `solid_queue:install` + `db/prepare` flow above at that point.

## Skills

When working on this project, use these skills for specialized assistance:

- **`rails-expert`** — Use for Active Record query optimization, Turbo Frames/Streams, Action Cable, Sidekiq/Solid Queue patterns, and Rails 7+ best practices. Reference docs available in `.agents/skills/rails-expert/references/`.
- **`frontend-design`** — Use for building UI components, pages, and layouts with TailwindCSS + DaisyUI. Useful for designing producer/admin dashboards, forms, and public-facing pages.

## Architecture

**Module name:** `Ruka` (defined in [config/application.rb](config/application.rb)), despite the repo directory being `multicorizador`.

**Purpose:** Multi-tenant SaaS platform for travel insurance quotation and comparison. Producers (insurance agents) create quotes that are sent to multiple insurance providers in parallel, results are compared, and policies are issued upon purchase.

### Database

**Engine:** SQLite3 (MVP). Schema is PostgreSQL-compatible for future migration.

**Key tables:** `companies`, `users`, `providers`, `insurance_plans`, `quotes`, `quote_results`, `policies`, `travelers`, `links`.

**Stay Postgres-portable — avoid SQLite-specific things:**
- No raw SQLite syntax in migrations/queries (no `PRAGMA`, no SQLite-only functions in `execute`/`find_by_sql`).
- Use `add_foreign_key` for every association, as already done — don't rely on implicit FKs.
- Prefer standard Rails migration DSL (`t.column`, `add_index`, etc.) over adapter-specific SQL so migrations replay unchanged on Postgres.
- `t.json` columns are fine as-is; when the app actually moves to Postgres, revisit them for `jsonb` (better indexing/query support), but don't over-engineer that now.
- Solid Queue/Cache/Cable currently each use their own SQLite file (see `config/database.yml`) — keep that separation in mind, since moving to Postgres means deciding whether they share the primary DB or get their own Postgres databases.

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

- **`/admin/*`** — Super admin: providers, insurance plans, users, dashboard.
- **`/producer/*`** — Active producers: quotes, travelers, policies, dashboard.
- **`/public/quotes/:token`** — Unauthenticated: view/update quotes via public token.
- **`/webhooks/:provider_slug`** — Provider webhook endpoint.

### Business Logic

**Quote lifecycle:** `draft` → `quoting` → `quoted` → `pending_payment` → `purchased` / `cancelled`. Also `client_pending` when shared via link.

**Provider integration:** Service objects in `app/services/insurance_providers/`. `BaseProvider` defines the interface (`quote`, `purchase_url`, `parse_webhook`, `valid_webhook?`). Providers register in `REGISTRY` hash by slug. `ExampleProvider` serves as reference implementation.

### Background Jobs

Solid Queue (DB-backed), started as a separate process in `Procfile.dev`. In production it runs inside Puma via `SOLID_QUEUE_IN_PUMA=true`.

**Jobs:**
- `QuoteJob` — Orchestrates quoting: updates status to `quoting`, enqueues `ProviderQuoteJob` for each active provider.
- `ProviderQuoteJob` — Calls provider API, creates `QuoteResult`. Retries 3x on `ProviderError` with 5s backoff.
- `WebhookProcessorJob` — Processes provider webhooks, creates `Policy` records.

### Frontend Stack

Propshaft (assets) + Importmap (JS) + TailwindCSS 4 + **Flowbite** + Hotwire (Turbo + Stimulus). No Node/webpack build step — CSS is compiled by `bin/rails tailwindcss:watch`.

**Styling: ALWAYS use Flowbite.** Flowbite is the ONLY styling library — do not reintroduce DaisyUI (removed), Bootstrap, or any other CSS framework. Component styling is written with Tailwind utilities in Flowbite's design language. A small set of reusable Flowbite-style component classes lives in `@layer components` at the top of `app/assets/tailwind/application.css` (`.btn`, `.card`, `.badge`, `.table`, `.stat`, `.alert`, `.input`, etc.) — these are OUR classes built with `@apply`, not a third-party plugin. Reuse them; extend that layer rather than scattering long utility strings across views.
- **Colors:** use real Tailwind palette tokens (`teal` is the brand/primary, matching the wizard's `--wz-teal`). Never use DaisyUI semantic classes (`bg-base-100`, `text-primary`, `text-error`, `data-theme`, etc.) — they no longer exist.
- **Icons:** **ALWAYS use Tabler Icons** (https://tabler.io/icons). Never inline hand-written SVGs, Heroicons, or other icon sets. Use the icon font classes (e.g. `<i class="ti ti-icon-name"></i>`) — pick whichever wiring is in place and stay consistent. Search Tabler for the most semantically accurate name before falling back to a generic one.
- **Flowbite JS (interactive components):** loaded via CDN (`flowbite.turbo.min.js`) in the layouts — use Flowbite's data-attributes (e.g. `data-dropdown-toggle`, `data-modal-target`) for dropdowns, modals, tabs, etc. The `.turbo` build re-initializes components on Turbo navigation, so prefer it over the plain `flowbite.min.js`.
- **Datepicker:** ALWAYS use the Flowbite datepicker (the `flowbite-datepicker` package). Date inputs are rendered as text fields via the `DatepickerInput` simple_form input (`as: :datepicker`) + the `datepicker` Stimulus controller, configured for `es` locale and ISO `yyyy-mm-dd` values (so Rails parses them natively). Never use `as: :date` (3 select boxes) or native `<input type="date">`.

**Forms:** `simple_form` gem with Flowbite wrappers. **ALWAYS use `simple_form_for` and `f.input`** — never use raw `form_for`, `form_with`, or manual `f.text_field`/`f.email_field` helpers. Available wrappers: `:default` (app forms), `:boolean` (checkboxes), `:auth` (Devise auth pages with compact labels), `:select`. See `config/initializers/simple_form.rb` and the custom inputs under `app/inputs/`.
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
