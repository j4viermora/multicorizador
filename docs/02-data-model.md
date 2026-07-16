# Modelo de Datos

## Diagrama de Entidades

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Company   │────<│    User     │     │   Provider  │
│  (tenant)   │     │  (devise)   │     │   (global)  │
└──────┬──────┘     └─────────────┘     └──────┬──────┘
       │                                         │
       │    ┌─────────────┐     ┌───────────────┐│
       └───<│   Traveler  │     │ InsurancePlan ││
       │    │  (tenant)   │     │   (global)    │┘
       │    └──────┬──────┘     └───────────────┘
       │           │
       │    ┌──────┴──────┐     ┌─────────────┐
       └───<│    Quote    │────<│ QuoteResult │
            │  (tenant)   │     │  (tenant)   │
            └──────┬──────┘     └──────┬──────┘
                   │                    │
            ┌──────┴──────┐     ┌──────┴──────┐
            │    Link     │     │    Policy   │
            │  (tenant)   │     │  (tenant)   │
            └─────────────┘     └─────────────┘
```

Nota: el modelo de comisiones (`CommissionContract`, `ProducerInvoice`, `PlatformInvoice`) que aparecía acá se eliminó del código — no hay tracking de comisión ni facturación por ahora.

## Descripción de Modelos

### Company
- `name`: string, obligatorio
- `currency`: string, obligatorio, default "USD"
- Relación: `has_many :users`, `has_many :quotes`, etc.

### User (Devise)
- `email`, `encrypted_password`: devise
- `role`: enum `[producer, super_admin]`
- `status`: enum `[pending, active, suspended]`
- `first_name`, `last_name`, `phone`
- Relación: `belongs_to :company` (nullable para super_admin)

### Provider
- `name`, `slug`: string, único
- `status`: enum `[active, inactive]`
- `config`: jsonb (endpoint, token, timeout, etc.)
- Relación: `has_many :insurance_plans`

### InsurancePlan
- `provider_id`: referencia
- `name`, `description`
- `coverage_details`: jsonb
- `status`: enum `[active, inactive]`

### Traveler
- `company_id`, `producer_id`
- `first_name`, `last_name`, `email`, `phone`, `document`, `birth_date`

### Quote
- `company_id`, `producer_id`, `traveler_id` (nullable en escenario B)
- `status`: enum de estados del flujo
- `public_token`: string único (para escenario B)
- `origin`, `destination`, `departure_date`, `return_date`
- `travelers_count`, `trip_type`
- `metadata`: jsonb (datos extra por aseguradora)
- `created_by`: "producer" o "client"

### QuoteResult
- `quote_id`, `provider_id`, `insurance_plan_id`
- `external_quote_id`, `raw_response`: jsonb
- `status`: `[pending, success, error]`
- Monetizados: `price`

### Link
- `company_id`, `quote_id`
- `token`: string único
- `purpose`, `expires_at`, `access_count`, `last_accessed_at`
- `status`: `[active, expired, revoked]`

### Policy
- `quote_result_id`, `company_id`
- `policy_number`, `status`, `issued_at`, `starts_at`, `ends_at`
- Monetizados: `premium`, `total`
- `webhook_payload`: jsonb

## Notas sobre JSONB en SQLite

SQLite no tiene JSONB nativo como PostgreSQL, pero ActiveRecord 8+ maneja `json` en SQLite transparentemente. En las migraciones usamos `t.json` que funciona igual para el MVP. Cuando migremos a PostgreSQL, cambiamos a `t.jsonb`.
