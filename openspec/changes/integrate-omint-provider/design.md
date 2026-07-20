## Context

`InsuranceProviders::BaseProvider` already defines the shared interface (`quote`, `purchase_url`, `parse_webhook`, `valid_webhook?`) that every provider implements, plus an `http_client` helper built on Faraday. Until now, every registered provider (`ExampleProvider`, `AssistCardFake`, `UniversalAssistanceFake`, `TravelAceFake`) either mocked its response in memory or never actually issued a request through `http_client` — so the `faraday` gem, though referenced in code, was never added to the Gemfile and would have raised `NameError` the first time any provider tried to use it.

Omint Assistance is the first real provider integration:
- Auth: OAuth2 client-credentials against a dedicated token endpoint, tokens expire in 60 minutes, and Omint's own manual explicitly warns against requesting a new token per quote request.
- Quoting: `POST /Quotation/CreateQuotationB2B` takes a fixed set of codes (`departureCode`, `destinationCode`, `productTypeCode`, ...) from closed enumerations and returns **all matching products in one response**, each with its own price — not a single price like every existing provider.
- `Quote#origin`/`Quote#destination` are plain strings today, filled from free-text inputs (except on the public landing page, which already has a country/region autocomplete widget wired to `ApplicationHelper#countries_autocomplete_data`).

## Goals / Non-Goals

**Goals:**
- Make Omint queryable end-to-end from `producer/quotes` like any other provider, producing real `QuoteResult` rows.
- Let a single provider call fan out into multiple `QuoteResult` rows without breaking the single-Hash contract existing providers rely on.
- Resolve `origin`/`destination` to Omint's codes deterministically (no silent mismatches), by constraining what values a `Quote` can actually hold.
- Keep the token exchange efficient and safe across multiple processes (Puma workers + Solid Queue), per Omint's explicit guidance.

**Non-Goals:**
- Purchase/emission (`CreateComplete`) and Omint webhooks — not documented yet; `purchase_url` raises `NotImplementedError` on purpose.
- A full redesign of `Quote#origin`/`destination` into normalized country-code columns — we reuse the existing string columns and an existing autocomplete widget, we don't change the schema.
- General-purpose destination-bucket abstraction reusable by other providers — Omint's 9-zone taxonomy is Omint-specific; if a future provider needs something similar, it can be extracted then (no premature abstraction now).

## Decisions

### 1. `#quote` may return an Array; `ProviderQuoteJob` normalizes with `Array.wrap`
**Decision**: Keep `BaseProvider#quote`'s contract as "returns a Hash or an Array of Hashes." `ProviderQuoteJob#perform` calls `Array.wrap(client.quote(quote))` and creates one `QuoteResult` per element.
**Alternative considered**: Filter Omint's request to a single `productCode` so `#quote` always returns one Hash, preserving the contract untouched. Rejected — it throws away the comparison value of showing several Omint plans side by side, which is the whole point of a multicotizador. `QuoteResult` already has no unique constraint on `(quote_id, provider_id)`, so the schema was already compatible with multiple rows per provider; the job was the only place assuming 1:1.

### 2. Token caching via `Rails.cache`, not an in-process memory cache
**Decision**: Cache the access token under `"omint:access_token:#{provider.id}"` in `Rails.cache` (Solid Cache) with `expires_in: 55.minutes` — 5 minutes short of Omint's real 60-minute expiry, matching the safety margin Omint's manual recommends.
**Alternative considered**: An in-memory `@token`/`@expires_at` instance/class variable, as shown in Omint's own C#/Node.js examples. Rejected — Puma (with multiple workers) and Solid Queue run as separate OS processes; an in-memory cache would be re-populated per process, multiplying token requests exactly as Omint's manual warns against. `Rails.cache.fetch` with a block is a single call site and needs no extra mutex for our volume.

### 3. Origin/destination resolved via the `countries` gem, not a hand-written string map
**Decision**: `OmintProvider` resolves `Quote#destination` to Omint's 9 zone codes by looking up the country (`ISO3166::Country.find_country_by_translated_names`) and mapping its `region`/`subregion` (e.g. `"South America"` → `ASU`, `"Western Asia"` → `EMO`, with `AR`/`UY` special-cased to `ARG`/`URU`). Broad region picks (`"Europa"`, `"Asia"`, `"África"`, `"Oceanía"`) map directly; `"América"` alone is intentionally left unmapped (ambiguous — Omint splits the Americas into 4 different zones) and raises `ProviderError`, forcing a specific-country selection. `Quote#origin` only resolves to `MAA` for Argentina; anything else raises `ProviderError` (Omint has no other departure country today).
**Alternative considered**: A flat Hash of literal strings ("Francia" → "EMO", "Alemania" → "EMO", ...) covering every country name we might see. Rejected — it doesn't scale (190+ countries) and drifts out of sync silently. The `countries` gem is already a dependency and gives us the classification for free.

### 4. Origin/destination inputs become a closed-vocabulary autocomplete everywhere, not just on the public landing page
**Decision**: Reuse the existing `country-autocomplete` Stimulus controller + `countries_autocomplete_data` helper (already used in `public/landing/show.html.erb`) in `producer/quotes/new`, `producer/quotes/edit`, and `public/quotes/show`.
**Alternative considered**: Leave those three forms as free text and rely on best-effort fuzzy matching inside `OmintProvider` at quote time. Rejected — free text makes the destination-resolution failure mode (`ProviderError: sin mapeo`) a runtime surprise for the producer instead of a UI constraint; reusing the widget that already exists is close to zero net-new code.

### 5. Secrets stay in `Provider#config` for now
**Decision**: `client_id`, `client_secret`, `token_endpoint`, `scope`, `agreement_number` all live in `Provider#config` (JSON column), matching how every other provider stores its config. `client_secret` is populated from `ENV["OMINT_CLIENT_SECRET"]` in `db/seeds.rb` rather than a literal string, so the real secret doesn't land in git history.
**Alternative considered**: Rails encrypted credentials (`config/credentials.yml.enc`). Explicitly deferred — the config-column pattern is what the rest of the codebase does today, and moving to credentials is a cross-provider decision, not something to bolt on for Omint alone.

## Risks / Trade-offs

- **[Risk]** `resolve_destination_code`/`resolve_departure_code` reject anything they can't classify (e.g. a still-free-typed legacy value from before this change, or the ambiguous `"América"` region) → **Mitigation**: raises `ProviderError`, which `ProviderQuoteJob` already turns into a `QuoteResult` with `status: "error"` plus the reason in `raw_response` — it never crashes the job, and existing quotes with legacy origin/destination values simply show an error result for Omint instead of a price, everything else continues to work as before.
- **[Risk]** Displaying several `QuoteResult` rows from the same provider on `producer/quotes/show` was never explicitly designed for — the view might read oddly with 5 "Omint Assistance" cards. → **Mitigation**: no schema change is needed to support it (verified no unique constraint), and the comparator already iterates `quote_results.successful` without assuming one-per-provider; visual grouping by provider, if wanted, is a follow-up UI task, not a blocker for this change.
- **[Risk]** Concurrent requests racing to refresh the cached token via `Rails.cache.fetch` could issue two token requests almost simultaneously. → **Mitigation**: accepted as-is — Omint's manual asks to avoid pathological per-request token fetching, not to guarantee zero duplicate requests ever; a stampede lock is not worth the complexity at current volume.
- **[Trade-off]** Omint only supports departure from Argentina; the departure/origin autocomplete still lets a producer type any country. → Accepted: rejecting non-Argentina origins with a clear `ProviderError` is enough for now; restricting the origin field itself to a single option is a product decision to revisit if/when a second provider needs a different origin story.

## Migration Plan

- No database migrations required.
- Rollout: `Provider` row seeded with `status: "inactive"`; flip to `"active"` per-company only after a real quote round-trips successfully against Omint's test environment (`base_url` pointed at `oaapp.eastus2.cloudapp.azure.com:8448`).
- Rollback: setting `status: "inactive"` on the `omint` provider immediately removes it from `Provider.active` and stops `ProviderQuoteJob` from being enqueued for it — no data cleanup needed since `QuoteResult` rows are provider-scoped and harmless to leave in place.

## Open Questions

- Should `quantityOfDays` (required only for annual products) come from a real `Quote` field instead of the hardcoded default (30)? No such field exists today.
- Is Omint's `grossPrice` always in ARS? The provider currently hardcodes `currency: "ARS"` — needs confirmation from Omint support if a company's `Money.default_currency` differs.
- How should `producer/quotes/show` visually group multiple `QuoteResult`s from the same provider? Left as a follow-up UI concern, not blocking this change.
