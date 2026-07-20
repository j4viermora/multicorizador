## 1. Dependencies & job contract

- [x] 1.1 Add `faraday` (~> 2.14) to the Gemfile and bundle install
- [x] 1.2 Update `ProviderQuoteJob#perform` to `Array.wrap(client.quote(quote))` and create one `QuoteResult` per element, preserving single-Hash behavior for existing providers

## 2. OmintProvider

- [x] 2.1 Create `app/services/insurance_providers/omint_provider.rb` implementing `self.slug`, `quote`, `purchase_url` (raises `NotImplementedError`)
- [x] 2.2 Implement OAuth2 client-credentials token fetch + `Rails.cache` caching (55 min TTL) keyed per `Provider#id`
- [x] 2.3 Implement single-retry-after-refresh on HTTP 401 during `CreateQuotationB2B`
- [x] 2.4 Implement request payload mapping (`productTypeCode`, `tariffTypeCode`, `agreementNumber`, dates, `passengerAges`, `quantityOfDays` for annual)
- [x] 2.5 Implement origin resolution (Argentina-only → `MAA`, else `ProviderError`)
- [x] 2.6 Implement destination resolution via `countries`/ISO3166 region/subregion classification, plus direct broad-region mapping (`Europa`/`Asia`/`África`/`Oceanía`)
- [x] 2.7 Implement response normalization (one hash per product in `products[]`) and non-2xx error handling
- [x] 2.8 Register `InsuranceProviders::OmintProvider` in `config/initializers/insurance_providers.rb`

## 3. Data & config

- [x] 3.1 Add `omint` `Provider` seed (`status: "inactive"`, `base_url` pointed at Omint's test environment, `client_secret` read from `ENV["OMINT_CLIENT_SECRET"]`)
- [x] 3.2 Add `omint` fixture to `test/fixtures/providers.yml` for tests

## 4. Forms — closed-vocabulary origin/destination

- [x] 4.1 Wire the existing `country-autocomplete` Stimulus controller + `countries_autocomplete_data` helper into `producer/quotes/new.html.erb`
- [x] 4.2 Same for `producer/quotes/edit.html.erb`
- [x] 4.3 Same for `public/quotes/show.html.erb`

## 5. Tests & verification

- [x] 5.1 Unit tests for `OmintProvider`: multi-product normalization, 401-retry-once, Argentina-only origin rejection, destination zone mapping (countries + broad regions), unmapped-destination rejection
- [x] 5.2 Run full `bin/rails test` suite and confirm no regressions
- [x] 5.3 Run `bin/rubocop` on all changed Ruby files

## 6. Follow-ups (not required for this change to land)

- [ ] 6.1 Validate a real quote round-trip against Omint's test environment (`oaapp.eastus2.cloudapp.azure.com:8448`) with real credentials before flipping `status: "active"`
- [ ] 6.2 Confirm with Omint support whether `grossPrice` is always ARS, or needs per-company currency handling
- [ ] 6.3 Decide how `producer/quotes/show` should visually group multiple `QuoteResult`s from the same provider
- [ ] 6.4 Implement purchase/emission (`CreateComplete`) once Omint provides that manual
