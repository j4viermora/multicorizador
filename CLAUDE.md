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

# Database (MariaDB runs in Docker — start it first)
docker compose up -d
bin/rails db:prepare
```

## Local Setup Gotchas

### Development and test run MariaDB, not SQLite

`docker-compose.yml` provides MariaDB 11.4 on **host port 3307** (3306 is usually taken by another project). Credentials default to `ruka` / `password` and are overridable via `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`.

**Never move development back to SQLite.** SQLite cannot distinguish `INTEGER` from `BIGINT`, so dumping `db/schema.rb` from it rewrites every `t.references` foreign key as `t.integer`. On MariaDB that is `INT(11)` against `BIGINT(20)` primary keys, and `db:prepare` then dies with `errno: 150 "Foreign key constraint is incorrectly formed"` — at deploy time, long after the bad schema was committed.

### JSON columns need an explicit `attribute ..., :json`

MariaDB has no native JSON type: it is an alias for `longtext` plus a `CHECK (json_valid(...))` constraint. Because `SHOW CREATE TABLE` reports `longtext`, Rails treats such columns as plain strings and stores `to_s` output (Ruby hash syntax), which fails the CHECK.

Every model with a JSON column therefore declares the cast explicitly — `attribute :config, :json` in `Provider`, and likewise in `InsurancePlan`, `Policy`, `Quote`, `QuoteResult`. **Add the same line whenever you introduce a new JSON column.**

Fixtures bypass the model, so they must contain JSON **strings**, not YAML hashes (Rails' fixture loader falls back to `to_yaml` for Hash values, producing `--- {}` which is not valid JSON):

```yaml
config: "{}"        # not: config: {}
```

### The collation is pinned on purpose

`config/database.yml` sets `collation: utf8mb4_unicode_ci`. MariaDB 11.4's default for utf8mb4 is `utf8mb4_uca1400_ai_ci`, which does not exist on MariaDB 10.x — and Rails bakes whatever it finds into `db/schema.rb`, producing a schema that only loads on 11.4+. Do not remove the pin.

### Boot loops on `Cannot delete or update a parent row`

A `db:schema:load` that fails partway through leaves the database half-built: MariaDB DDL is not transactional, so the tables it managed to create stay, but `schema_migrations` — written last — never appears. On the next boot `db:prepare` sees no `schema_migrations`, concludes the database is empty and replays the schema, whose `force: :cascade` DROPs now fail against the leftover foreign keys. Every subsequent boot fails the same way.

Recover with:

```bash
bin/rails db:reset_hard                                    # development
DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails db:reset_hard   # anywhere else
```

It drops every table with `FOREIGN_KEY_CHECKS=0` (sidestepping the ordering problem) and reloads the schema. **Destructive** — it is a recovery tool, not routine maintenance.

### Do not chain `db:drop db:prepare` in one invocation

With multiple databases configured, `bin/rails db:drop db:prepare` runs the seeds but ends with an empty database. Run them separately:

```bash
bin/rails db:drop
bin/rails db:prepare
```

### `css: bin/rails tailwindcss:watch` exits immediately and tears down `bin/dev`

Without a TTY (terminals spawned by some editors, Docker without `tty: true`, CI), the Tailwind CLI exits as soon as `stdin` closes. The `css` process compiles once and exits, which makes Foreman/overmind SIGTERM **all** other processes (web + worker), so `bin/dev` looks like it crashes right after boot.

`Procfile.dev` is already pinned to `bin/rails tailwindcss:watch[always]` to keep the watcher alive. **Do not revert it to the bare `tailwindcss:watch`** — it will break non-TTY environments again.


## Skills

When working on this project, use these skills for specialized assistance:

- **`rails-expert`** — Use for Active Record query optimization, Turbo Frames/Streams, Action Cable, Sidekiq/Solid Queue patterns, and Rails 7+ best practices. Reference docs available in `.agents/skills/rails-expert/references/`.
- **`frontend-design`** — Use for building UI components, pages, and layouts with TailwindCSS + DaisyUI. Useful for designing producer/admin dashboards, forms, and public-facing pages.

## Architecture

**Module name:** `Ruka` (defined in [config/application.rb](config/application.rb)), despite the repo directory being `multicorizador`.

**Purpose:** Multi-tenant SaaS platform for travel insurance quotation and comparison. Producers (insurance agents) create quotes that are sent to multiple insurance providers in parallel, results are compared, and policies are issued upon purchase.

### Database

**Engine:** MariaDB (`mysql2` adapter) in every environment — development and test via `docker-compose.yml`, production via `APP_DATABASE_URL`.

**Key tables:** `companies`, `users`, `providers`, `insurance_plans`, `quotes`, `quote_results`, `policies`, `travelers`, `links`.

**Conventions:**
- Use `add_foreign_key` for every association, as already done — don't rely on implicit FKs.
- Prefer the standard Rails migration DSL (`t.column`, `add_index`, etc.) over adapter-specific SQL.
- Foreign keys must be `bigint`, matching the `bigint` primary keys. `t.references` does this automatically; never hand-write `t.integer` for an FK.
- JSON columns need `attribute :name, :json` on the model — see the Local Setup Gotchas above.
- **Single database.** Solid Queue/Cache/Cable keep their tables alongside the application's, created by ordinary migrations in `db/migrate`. The production database user is only granted privileges on its own schema and cannot create the extra databases a multi-database setup needs.
- Because of that, none of the Solid engines declare `connects_to` — not in `config/environments/*.rb`, not in `cache.yml`, not in `cable.yml`. **Do not add it back**, and do not reintroduce `queue`/`cache`/`cable` entries in `database.yml`: that is what made all four connection roles write to the same `ar_internal_metadata` row, so Rails' schema-up-to-date check disagreed with itself and replayed `schema.rb` (`force: :cascade` DROP) on every boot.

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

Kamal (`bin/kamal`). Config in [config/deploy.yml](config/deploy.yml). Requires `RAILS_MASTER_KEY` and `APP_DATABASE_URL` (deliberately *not* named `DATABASE_URL` — Rails auto-merges that one into the primary config and lets the URL scheme override the adapter, which breaks on `mariadb://` URLs; see the comment in `config/database.yml`). SSL via Let's Encrypt proxy.
