## ADDED Requirements

### Requirement: A provider's quote result may be a single result or a collection of results
The system SHALL accept, from any `InsuranceProviders::BaseProvider` subclass's `#quote` method, either a single normalized result Hash (existing behavior) or an Array of normalized result Hashes, and SHALL treat both forms identically when persisting results.

#### Scenario: A provider returning a single Hash is unaffected
- **WHEN** `ProviderQuoteJob` calls `#quote` on a provider that returns a single Hash (e.g. any existing fake provider)
- **THEN** exactly one `QuoteResult` with `status: "success"` is created, matching current behavior

#### Scenario: A provider returning an Array creates one result per element
- **WHEN** `ProviderQuoteJob` calls `#quote` on a provider that returns an Array of N normalized Hashes
- **THEN** N separate `QuoteResult` records are created, each with `status: "success"`, its own `price`, and its own `raw_response`, all linked to the same `quote` and `provider`

### Requirement: A provider error still yields a single error result
The system SHALL continue to create exactly one `QuoteResult` with `status: "error"` when a provider's `#quote` call raises, regardless of whether that provider normally returns single or multiple results.

#### Scenario: An exception during quoting produces one error result
- **WHEN** a provider's `#quote` call raises `ProviderError` (or any other exception, outside development)
- **THEN** exactly one `QuoteResult` with `status: "error"` is created for that `quote`/`provider` pair, with the failure reason captured in `raw_response`
