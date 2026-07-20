## Why

Ruka today only quotes against fake/reference providers (`ExampleProvider`, `*Fake`). Omint Assistance gave us real B2B API credentials (`CreateQuotationB2B` — OAuth2 client-credentials auth, returns priced products for a travel insurance catalog) and it needs to become the first real, production-usable provider in the comparator. Doing so exposed two gaps in the existing provider architecture that had to be closed first: `BaseProvider#http_client` depended on the `faraday` gem, which was never actually added to the Gemfile (no real provider had exercised it), and the provider contract assumed one `QuoteResult` per provider per quote — Omint's endpoint returns a whole catalog of priced products (OA 30, OA 70, OA 100...) in a single call, not one price.

## What Changes

- Add `faraday` as a real dependency (`Gemfile`) — required for any provider that calls a real HTTP API; previously referenced by `BaseProvider` but never installed.
- Add `InsuranceProviders::OmintProvider`: OAuth2 client-credentials auth against Omint's token endpoint, with the token cached in `Rails.cache` (shared across Puma/Solid Queue processes) and a single retry-after-token-refresh on `401`.
- Extend the provider→job contract so `#quote` may return an Array of normalized result hashes (one per priced product) instead of only a single Hash. `ProviderQuoteJob` now does `Array.wrap(client.quote(quote))` and creates one `QuoteResult` per element — existing providers (which return a single Hash) are unaffected.
- Resolve `Quote#origin`/`Quote#destination` to Omint's fixed origin/destination codes via the `countries` (ISO3166) gem's region/subregion data, instead of fuzzy text matching — Omint only accepts a closed set of codes (e.g. `EMO`, `ASU`, `NAC`, `ARG`, `URU`) and only supports departures from Argentina today.
- Replace the free-text `origin`/`destination` inputs in `producer/quotes/new`, `producer/quotes/edit`, and `public/quotes/show` with the same country/region autocomplete widget already used on the public landing wizard (`country-autocomplete` Stimulus controller + `countries_autocomplete_data` helper), so values entering the mapping above are consistent everywhere, not just on the landing page.
- Store Omint's non-secret config (`base_url`, `token_endpoint`, `agreement_number`, ...) on `Provider#config`, matching the existing provider pattern; `client_secret` also lives there for now (read from `ENV["OMINT_CLIENT_SECRET"]` in seeds, not committed in plaintext), with a documented follow-up to move it to Rails credentials if/when this becomes standard practice for real providers.
- Register the `Provider` record (slug `omint`) as `status: "inactive"` until validated against Omint's test environment.
- **Out of scope**: purchase/emission (`CreateComplete` endpoint) and any Omint webhook — `purchase_url` raises `NotImplementedError` explicitly; Omint's manual for that flow hasn't been provided yet.

## Capabilities

### New Capabilities
- `omint-provider`: Real integration with Omint Assistance's `CreateQuotationB2B` B2B API — OAuth2 token management, request/response mapping, origin/destination code resolution, error handling.
- `multi-product-quote-results`: Generic support in the quoting pipeline for a single provider call returning multiple priced products, each surfaced as an independent `QuoteResult`.

### Modified Capabilities
(none — no existing `openspec/specs/*` capability covers provider integration or the quote/results pipeline yet)

## Impact

- **Dependencies**: `faraday` (~> 2.14) added to `Gemfile`/`Gemfile.lock`.
- **Code**: `app/services/insurance_providers/omint_provider.rb` (new), `app/jobs/provider_quote_job.rb` (result fan-out), `config/initializers/insurance_providers.rb` (registration), `db/seeds.rb` (Provider record).
- **Views**: `app/views/producer/quotes/new.html.erb`, `app/views/producer/quotes/edit.html.erb`, `app/views/public/quotes/show.html.erb` — origin/destination now use the country-autocomplete widget.
- **Tests**: `test/services/insurance_providers/omint_provider_test.rb` (new), `test/fixtures/providers.yml` (`omint` fixture).
- **Docs**: `docs/09-omint-integration-plan.md` (integration reference).
- No database migrations — `Provider#config` and `QuoteResult` already support everything needed (no unique constraint on `quote_id, provider_id`).
