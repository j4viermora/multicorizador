# Integración de Proveedores (Strategy Pattern)

## Propósito

Cada aseguradora tiene una API diferente: endpoints distintos, autenticación distinta, formatos de request/response distintos. El Strategy Pattern abstrae estas diferencias detrás de una interfaz unificada.

## Estructura

```
app/services/insurance_providers/
├── base_provider.rb
├── provider_registry.rb
└── example_provider.rb
```

## Cómo agregar una nueva aseguradora

### Paso 1: Crear la clase del proveedor

```ruby
# app/services/insurance_providers/mi_seguro_provider.rb
module InsuranceProviders
  class MiSeguroProvider < BaseProvider
    def self.slug = "mi_seguro"

    def quote(quote)
      response = http_client.post("/quotes", {
        origin: quote.origin,
        destination: quote.destination,
        departure: quote.departure_date,
        return: quote.return_date,
        travelers: quote.travelers_count
      })

      data = response.body
      {
        external_quote_id: data["quote_id"],
        price_cents: data["price"]["cents"],
        currency: data["price"]["currency"],
        plan_name: data["plan"]["name"],
        valid_until: data["expires_at"]
      }
    end

    def purchase_url(quote_result)
      "#{provider.config_for(:checkout_url)}?quote_id=#{quote_result.external_quote_id}&callback=#{provider.config_for(:callback_url)}"
    end

    def parse_webhook(payload)
      {
        policy_number: payload["policy"]["number"],
        issued_at: Time.parse(payload["policy"]["issued_at"]),
        starts_at: Date.parse(payload["policy"]["start_date"]),
        ends_at: Date.parse(payload["policy"]["end_date"]),
        premium_cents: payload["policy"]["premium_cents"],
        total_cents: payload["policy"]["total_cents"]
      }
    end

    def valid_webhook?(request)
      token = request.headers["X-MiSeguro-Token"]
      ActiveSupport::SecurityUtils.secure_compare(token, provider.config_for(:webhook_token))
    end
  end
end
```

### Paso 2: Registrar el proveedor

```ruby
# config/initializers/insurance_providers.rb
InsuranceProviders.register(InsuranceProviders::MiSeguroProvider)
```

### Paso 3: Crear el registro en la base de datos

```ruby
Provider.create!(
  name: "Mi Seguro",
  slug: "mi_seguro",
  config: {
    base_url: "https://api.miseguro.com/v1",
    checkout_url: "https://checkout.miseguro.com",
    timeout: 30,
    webhook_token: "sekret_token_123"
  }
)
```

### Paso 4: Crear planes (opcional)

```ruby
InsurancePlan.create!(provider: provider, name: "Plan Básico", description: "...")
```

## Contrato de la interfaz

Cada proveedor DEBE implementar:

| Método | Retorno | Descripción |
|--------|---------|-------------|
| `self.slug` | String | Identificador único del proveedor |
| `quote(quote)` | Hash | Consulta la API y retorna hash normalizado |
| `purchase_url(quote_result)` | String | URL para que el cliente complete el pago |
| `parse_webhook(payload)` | Hash | Normaliza el payload del webhook a atributos de Policy |
| `valid_webhook?(request)` | Boolean | Valida autenticidad del webhook |

## Hash normalizado de `quote`

```ruby
{
  external_quote_id: "string",   # ID de la cotización en el proveedor
  price_cents: 10000,            # Precio en centavos
  currency: "USD",               # ISO 4217
  plan_name: "Plan Básico",      # Nombre del plan (opcional)
  valid_until: Time              # Hasta cuándo es válida la cotización (opcional)
}
```

## Hash normalizado de `parse_webhook`

```ruby
{
  policy_number: "POL-12345",
  issued_at: Time,
  starts_at: Date,
  ends_at: Date,
  premium_cents: 10000,
  total_cents: 10000
}
```

## Manejo de errores

Si un proveedor falla (timeout, error 5xx, formato inesperado), el `ProviderQuoteJob`:
1. Crea un `QuoteResult` con `status: error` y el mensaje en `raw_response`.
2. Reintenta hasta 3 veces con backoff de 5 segundos.
3. Si sigue fallando, marca como error definitivo.
4. El comparador ignora los `QuoteResult` con `status: error`.

## Testing

Para probar sin APIs reales, usamos `ExampleProvider` que genera cotizaciones aleatorias. En tests se puede stubbear:

```ruby
allow_any_instance_of(InsuranceProviders::MiSeguroProvider)
  .to receive(:quote).and_return({ ... })
```
