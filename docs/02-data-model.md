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
            └─────────────┘     └──────┬──────┘
                                       │
                              ┌────────┴────────┐
                              │ ProducerInvoice │
                              │   (tenant)      │
                              └─────────────────┘

┌─────────────────────────┐     ┌─────────────────────────┐
│   CommissionContract    │     │   PlatformInvoice       │
│       (global)          │     │      (global)           │
└─────────────────────────┘     └─────────────────────────┘
```

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
- Relación: `has_many :insurance_plans`, `has_many :commission_contracts`

### InsurancePlan
- `provider_id`: referencia
- `name`, `description`
- `coverage_details`: jsonb
- `status`: enum `[active, inactive]`

### CommissionContract
- `provider_id`, `producer_id` (nullable para default)
- `provider_commission_rate`: decimal (ej: 0.4000)
- `producer_share_rate`: decimal (ej: 0.5000)
- `valid_from`, `valid_until`
- Resolución: específico (provider + producer) → default (provider + null)

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
- Monetizados: `price`, `provider_commission`, `platform_commission`, `producer_commission`

### Link
- `company_id`, `quote_id`
- `token`: string único
- `purpose`, `expires_at`, `access_count`, `last_accessed_at`
- `status`: `[active, expired, revoked]`

### Policy
- `quote_result_id`, `company_id`
- `policy_number`, `status`, `issued_at`, `starts_at`, `ends_at`
- Monetizados: `premium`, `total`, `provider_commission`, `platform_commission`, `producer_commission`
- `producer_commission_status`: `[pending, invoiced, paid]`
- `webhook_payload`: jsonb

### ProducerInvoice
- `company_id`, `producer_id`
- `period_start`, `period_end`
- `total_commission`: monetizado
- `status`: `[draft, pending, paid]`
- Relación: `has_many :policies, through: :producer_invoice_policies`

### PlatformInvoice
- `provider_id`, `period_start`, `period_end`
- `total_commission`: monetizado
- `status`: `[draft, pending, paid]`

## Notas sobre JSONB en SQLite

SQLite no tiene JSONB nativo como PostgreSQL, pero ActiveRecord 8+ maneja `json` en SQLite transparentemente. En las migraciones usamos `t.json` que funciona igual para el MVP. Cuando migremos a PostgreSQL, cambiamos a `t.jsonb`.
