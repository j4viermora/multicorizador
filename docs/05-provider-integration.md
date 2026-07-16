# Integración de Proveedores (Strategy Pattern)

## Propósito

Cada aseguradora tiene una API diferente: endpoints distintos, autenticación distinta, formatos de request/response distintos. El Strategy Pattern abstrae estas diferencias detrás de una interfaz unificada (`InsuranceProviders::BaseProvider`).

## Estructura

```
app/services/insurance_providers.rb          # REGISTRY (module-level)
app/services/insurance_providers/
├── base_provider.rb
├── example_provider.rb                      # referencia (mock, con un bug conocido — ver abajo)
├── assist_card_fake.rb
├── universal_assistance_fake.rb
└── travel_ace_fake.rb

config/initializers/insurance_providers.rb    # registro de todas las clases al boot
```

## Checklist rápido para agregar una aseguradora nueva

1. Crear la clase en `app/services/insurance_providers/mi_seguro_provider.rb`.
2. Registrarla en `config/initializers/insurance_providers.rb`.
3. Crear el `Provider` en la base (nombre, slug, config, status: "active").
4. Probar una búsqueda real desde `/cotizar/:slug` y confirmar que aparece un `QuoteResult` con `status: success`.
5. Si la aseguradora manda webhook al comprar, probarlo con un payload de ejemplo y confirmar que crea la `Policy`.

---

## Paso 1: Crear la clase del proveedor

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
        external_quote_id: payload["quote_id"],
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
      return false unless token
      ActiveSupport::SecurityUtils.secure_compare(token, provider.config_for(:webhook_token).to_s)
    end
  end
end
```

Notar `self.slug` como método de clase — es lo que usa `InsuranceProviders::REGISTRY` para mapear el `Provider#slug` de la base de datos a esta clase Ruby. **Deben coincidir exactamente.**

El método `quote` recibe el `Quote` (o `QuoteSearch`, en la búsqueda pública anónima — ambos responden a `origin`, `destination`, `departure_date`, `return_date`, `travelers_count`, `trip_type`, `metadata`), así que no asumas que siempre es un `ActiveRecord::Base`.

`http_client` (heredado de `BaseProvider`) ya viene armado con Faraday apuntando a `provider.config_for(:base_url)` — no hace falta instanciar Faraday a mano salvo que necesites headers/auth especiales (podés sobreescribir `http_client` en tu clase si es así).

## Paso 2: Registrar el proveedor

```ruby
# config/initializers/insurance_providers.rb
Rails.application.config.to_prepare do
  InsuranceProviders.register(InsuranceProviders::ExampleProvider)
  InsuranceProviders.register(InsuranceProviders::AssistCardFake)
  InsuranceProviders.register(InsuranceProviders::UniversalAssistanceFake)
  InsuranceProviders.register(InsuranceProviders::TravelAceFake)
  InsuranceProviders.register(InsuranceProviders::MiSeguroProvider) # ← nueva línea
end
```

Está dentro de `to_prepare` porque en desarrollo las clases se recargan (`config.eager_load = false`); si registrás por fuera de ese bloque, un reload puede dejar el registro apuntando a una clase vieja.

## Paso 3: Crear el registro en la base de datos

Desde `bin/rails console`, seeds, o el panel `/admin/providers`:

```ruby
Provider.create!(
  name: "Mi Seguro",
  slug: "mi_seguro",
  status: "active",
  config: {
    base_url: "https://api.miseguro.com/v1",
    checkout_url: "https://checkout.miseguro.com",
    timeout: 30,
    webhook_token: "sekret_token_123"
  }
)
```

`status` es un string libre ("active"/"inactive"), no un enum — `Provider.active` filtra por `status: "active"`. Solo los proveedores activos se consultan en cada búsqueda (`Provider.active` en `QuoteSearchService` y en `QuoteJob`).

⚠️ **Bug conocido en el formulario `/admin/providers/new` y `/edit`:** el campo "Configuración (JSON)" es un `text_area` que manda un string plano, pero el controller permite `config: {}` (un hash anidado). Como los tipos no coinciden, Rails strong parameters **descarta el campo en silencio** — guardar desde el form no persiste el `config`. Hasta que se arregle ese form, seteá `config` por consola o seeds como en el ejemplo de arriba.

## Paso 4: Crear planes (opcional)

```ruby
InsurancePlan.create!(provider: provider, name: "Plan Básico", description: "...")
```

`InsurancePlan` hoy es informativo (para el catálogo del admin); `QuoteResult` no lo referencia automáticamente — si tu integración necesita mapear el plan devuelto por la API a un `InsurancePlan` específico, hacelo dentro de tu clase `quote`/`parse_webhook`.

## Contrato de la interfaz

Cada proveedor DEBE implementar:

| Método | Retorno | Descripción |
|--------|---------|-------------|
| `self.slug` | String | Identificador único, debe matchear `Provider#slug` |
| `quote(quote)` | Hash | Consulta la API y retorna hash normalizado |
| `purchase_url(quote_result)` | String | URL para que el cliente complete el pago |
| `parse_webhook(payload)` | Hash | Normaliza el payload del webhook a atributos de Policy |
| `valid_webhook?(request)` | Boolean | Valida autenticidad del webhook (default: `true` si no se sobreescribe) |

## Hash normalizado de `quote`

```ruby
{
  external_quote_id: "string",       # ID de la cotización en el proveedor (obligatorio si vas a recibir webhook)
  price_cents: 10000,                # Precio total en centavos
  price_per_person_cents: 5000,      # Opcional, se usa en el detalle de precio
  currency: "USD",                   # ISO 4217
  plan_name: "Plan Básico",          # Nombre del plan (opcional)
  provider_name: "Mi Seguro",        # Opcional, si no se usa el nombre del Provider
  coverage: [                        # Opcional, se muestra en la landing pública
    { name: "Asistencia médica", amount: "USD 150.000" }
  ],
  valid_until: Time                  # Opcional
}
```

## Hash normalizado de `parse_webhook`

```ruby
{
  external_quote_id: "string",  # OBLIGATORIO: es la clave con la que WebhookProcessorJob busca el QuoteResult
  policy_number: "POL-12345",
  issued_at: Time,
  starts_at: Date,
  ends_at: Date,
  premium_cents: 10000,
  total_cents: 10000
}
```

⚠️ **`external_quote_id` es obligatorio en este hash** — `WebhookProcessorJob` hace `QuoteResult.find_by(external_quote_id: parsed[:external_quote_id])`; si falta, el `find_by` devuelve `nil` y el webhook se descarta sin crear la `Policy`, sin ningún error visible. `ExampleProvider#parse_webhook` (la implementación de referencia) hoy **no** devuelve esta clave — es un bug conocido en el mock, no lo copies al escribir tu proveedor real.

Ver `docs/06-webhook-handling.md` para el resto del flujo de webhooks (autenticación, idempotencia, logging).

## Manejo de errores en la consulta

Si un proveedor falla (timeout, error 5xx, formato inesperado):

- En el flujo del productor (`QuoteJob` → `ProviderQuoteJob`): se crea un `QuoteResult` con `status: "error"` y el mensaje en `raw_response`, y reintenta hasta 3 veces con backoff de 5 segundos (`retry_on InsuranceProviders::BaseProvider::ProviderError`).
- En la búsqueda pública anónima (`Public::LandingController`): la llamada es síncrona (sin job) — cada proveedor se consulta con su propio `begin/rescue` dentro de `QuoteSearchService#call`, y los que fallan simplemente no aparecen en los resultados mostrados (no se persiste `QuoteResult` de error en este flujo).
- En ambos casos, el comparador de resultados ignora los `QuoteResult` con `status: error`.

## Testing

El proyecto usa **Minitest** (no RSpec), corrido con `bin/rails test`. Para no depender de la API real de la aseguradora, stubbeá el método `quote`/`parse_webhook` de tu clase:

```ruby
# test/services/insurance_providers/mi_seguro_provider_test.rb
require "test_helper"

class InsuranceProviders::MiSeguroProviderTest < ActiveSupport::TestCase
  test "normaliza la respuesta de la API" do
    provider = providers(:mi_seguro) # fixture
    client = InsuranceProviders::MiSeguroProvider.new(provider)

    stub_request(:post, "https://api.miseguro.com/v1/quotes")
      .to_return(
        status: 200,
        body: { quote_id: "abc123", price: { cents: 5000, currency: "USD" }, plan: { name: "Básico" }, expires_at: 1.day.from_now }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    quote = quotes(:draft_quote)
    result = client.quote(quote)

    assert_equal "abc123", result[:external_quote_id]
    assert_equal 5000, result[:price_cents]
  end
end
```

Si preferís no pegarle a HTTP ni con stubs (`webmock`/`vcr` no están instalados por defecto en el Gemfile — agregalos si los necesitás), podés simplemente redefinir el método en el test:

```ruby
client = InsuranceProviders::MiSeguroProvider.new(providers(:mi_seguro))
def client.quote(_quote)
  { external_quote_id: "abc123", price_cents: 5000, currency: "USD", plan_name: "Básico" }
end
```

Para probar el flujo completo end-to-end sin mocks, usá los proveedores `*_fake` existentes (`AssistCardFake`, `UniversalAssistanceFake`, `TravelAceFake`) como referencia de "aseguradora fake con precios calculados en memoria" — son los que corren en desarrollo/demo.
