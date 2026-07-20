## ADDED Requirements

### Requirement: Omint OAuth2 token acquisition and caching
The system SHALL obtain an OAuth2 access token from Omint's client-credentials token endpoint using the `Provider#config` values (`client_id`, `client_secret`, `token_endpoint`, `scope`), and SHALL cache that token in `Rails.cache` for 55 minutes so it is not requested more than once per that window per provider record, regardless of how many `Puma`/`Solid Queue` processes are running.

#### Scenario: Token is reused across consecutive quote requests
- **WHEN** two `OmintProvider#quote` calls happen within 55 minutes of each other for the same `Provider` record
- **THEN** only the first call fetches a new token from Omint's token endpoint; the second call reuses the cached token

#### Scenario: Token is refreshed once after expiring or being rejected
- **WHEN** a quote request to `CreateQuotationB2B` responds with HTTP 401
- **THEN** the cached token is discarded, a new token is fetched, and the quote request is retried exactly once with the new token

### Requirement: Quote request mapping to Omint's CreateQuotationB2B fields
The system SHALL build a `CreateQuotationB2B` request body from a `Quote` (or any object responding to `origin`, `destination`, `departure_date`, `return_date`, `trip_type`, `ages`), mapping `trip_type` to `productTypeCode` (`single`/`multi_trip` → `"S"`, `annual` → `"A"`), setting `tariffTypeCode` to `"B"`, `agreementNumber` from `Provider#config`, `dateSince`/`dateUntil` from the quote's dates (defaulting `dateUntil` to `departure_date + 10.days` when `return_date` is absent), and `passengerAges` from the quote's ages (defaulting to `[30]` when empty). When `productTypeCode` is `"A"`, the request SHALL also include `quantityOfDays`.

#### Scenario: Single-trip quote is mapped to productTypeCode "S"
- **WHEN** a `Quote` with `trip_type: "single"` is quoted against Omint
- **THEN** the request body sent to `CreateQuotationB2B` has `productTypeCode: "S"` and no `quantityOfDays` key

#### Scenario: Annual quote includes quantityOfDays
- **WHEN** a `Quote` with `trip_type: "annual"` is quoted against Omint
- **THEN** the request body has `productTypeCode: "A"` and includes a `quantityOfDays` value

### Requirement: Origin resolves only to Argentina's departure code
The system SHALL resolve a quote's `origin` to Omint's `departureCode` only when the origin identifies Argentina (via `countries`/ISO3166 lookup), mapping it to `"MAA"`. Any other resolvable or unresolvable origin SHALL raise `InsuranceProviders::BaseProvider::ProviderError` before any HTTP request is made.

#### Scenario: Argentina origin resolves successfully
- **WHEN** a quote's `origin` is `"Argentina"`
- **THEN** the request body's `departureCode` is `"MAA"`

#### Scenario: Non-Argentina origin is rejected
- **WHEN** a quote's `origin` is `"Brasil"` (or any country other than Argentina)
- **THEN** `OmintProvider#quote` raises `ProviderError` mentioning Argentina, and no HTTP request is made to Omint

### Requirement: Destination resolves to one of Omint's nine fixed zones
The system SHALL resolve a quote's `destination` to one of Omint's destination codes (`ARG`, `URU`, `ASU`, `NAC`, `MAC`, `EMO`, `AAA`, `OCE`, `MUC`) using: (a) a direct match for the broad region labels `"Europa"`, `"Asia"`, `"África"`, `"Oceanía"`; or (b) a country lookup via `countries`/ISO3166, classifying by the country's region/subregion (Argentina → `ARG`, Uruguay → `URU`, other South America → `ASU`, Northern America → `NAC`, Central America/Caribbean → `MAC`, Western Asia → `EMO`, Europe → `EMO`, other Asia/Africa → `AAA`, Oceania → `OCE`). A destination that cannot be classified by either path (including the ambiguous broad region `"América"`) SHALL raise `ProviderError` without making an HTTP request.

#### Scenario: Country destination resolves via region/subregion
- **WHEN** a quote's `destination` is `"Francia"`
- **THEN** the request body's `destinationCode` is `"EMO"`

#### Scenario: Broad region destination resolves directly
- **WHEN** a quote's `destination` is `"Europa"`
- **THEN** the request body's `destinationCode` is `"EMO"` without a country lookup

#### Scenario: Unclassifiable destination is rejected
- **WHEN** a quote's `destination` is `"América"` or any value that does not match a known country or region
- **THEN** `OmintProvider#quote` raises `ProviderError` mentioning the destination, and no HTTP request is made to Omint

### Requirement: Successful quote response is normalized per product
The system SHALL convert a successful `CreateQuotationB2B` response into one normalized result hash per entry in the response's `products` array, each with `external_quote_id` (the response's `id`), `price_cents` (the product's `grossPrice` converted to cents), `currency: "ARS"`, and `plan_name` (the product's `denomination`).

#### Scenario: Multiple products yield multiple normalized results
- **WHEN** `CreateQuotationB2B` responds with 200 and a `products` array containing 3 entries
- **THEN** `OmintProvider#quote` returns an Array of 3 normalized hashes, each with its own `plan_name` and `price_cents`

### Requirement: Non-2xx responses raise a provider error
The system SHALL raise `ProviderError` (including the HTTP status and any `errors` message from the response body) when `CreateQuotationB2B` responds with a non-success status other than a successfully-retried 401.

#### Scenario: 400 response is surfaced as a provider error
- **WHEN** `CreateQuotationB2B` responds with HTTP 400 and an `errors` array in the body
- **THEN** `OmintProvider#quote` raises `ProviderError` whose message includes the response's error detail

### Requirement: Purchase/emission is explicitly unsupported
The system SHALL raise `NotImplementedError` from `OmintProvider#purchase_url` until Omint's purchase/emission (`CreateComplete`) flow is documented and implemented.

#### Scenario: Attempting to purchase raises a clear error
- **WHEN** `OmintProvider#purchase_url` is called for any `QuoteResult`
- **THEN** a `NotImplementedError` is raised explaining that Omint's purchase flow is not yet implemented
