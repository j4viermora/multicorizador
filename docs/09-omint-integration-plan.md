# Plan de Integración: Omint Assistance (CreateQuotationB2B)

> Fuente: manual PDF entregado por Omint (`CreateQuotationB2B`, generado 05/06/2026). Credenciales y URLs abajo están tomadas de ese documento — **no** commitear el `client_secret` real, va a Rails credentials (ver Paso 2).

## 0. Resumen del proveedor

- **Auth:** OAuth2 Client Credentials contra `https://core.omintassistance.com.ar/connect/token`. Token Bearer, expira a los 60 min (3600s).
- **Cotización:** `POST /Quotation/CreateQuotationB2B`
  - Test: `https://oaapp.eastus2.cloudapp.azure.com:8448/Quotation/CreateQuotationB2B`
  - Prod: `https://api.omintassistance.com.ar/Quotation/CreateQuotationB2B`
- **Particularidad clave:** este endpoint **no cotiza un plan — devuelve una lista de productos** (todo el catálogo del acuerdo, o filtrado por `productTypeCode`/`productCode`) con su precio cada uno. No emite voucher (eso es `CreateComplete`, fuera de alcance de este plan).
- Acuerdo asignado: `agreementNumber: 3329`, mercado único (Argentina, no hace falta enviar `marketId`).

## 1. Decisiones de diseño que necesitan tu OK antes de codear

Estas dos rompen con el patrón actual (`docs/05-provider-integration.md`) y conviene decidirlas ahora, no a mitad de implementación.

### 1.1 Un proveedor → múltiples resultados

Hoy `BaseProvider#quote` devuelve **un** Hash y `ProviderQuoteJob` crea **un** `QuoteResult`. Omint devuelve un array de productos (ej. OA 30, OA 50, OA 70...) en una sola llamada.

**Opción A — Filtrar a un solo producto** (mínimo cambio): mapear `trip_type`/`travelers_count`/duración del viaje a un `productCode` específico y devolver solo ese, respetando el contrato actual tal cual.
Contras: se pierde el catálogo — el usuario no ve "OA 30 vs OA 70 vs OA 100 de Omint", que es justo el tipo de comparación que un multicotizador debería ofrecer.

**Opción B — Extender el contrato para soportar arrays** (recomendada): permitir que `quote(quote)` devuelva un Hash (como hoy, proveedores existentes sin cambios) **o** un Array de Hashes, y que `ProviderQuoteJob` itere y cree un `QuoteResult` por producto. `QuoteResult` ya no tiene constraint único `(quote, provider)`, así que el esquema soporta esto sin migraciones.

Recomiendo **B**. Es un cambio chico y localizado (`ProviderQuoteJob#perform`, línea donde hace `client.quote(quote)` → `QuoteResult.create!`), no rompe los providers fake existentes (siguen devolviendo un Hash), y habilita que a futuro cualquier proveedor con catálogo múltiple use el mismo mecanismo.

### 1.2 Mapeo de `origin`/`destination` (texto libre) → códigos Omint

`Quote#origin`/`#destination` son **texto libre** ingresado por el productor (placeholder "Ej: Argentina" / "Ej: Europa" — ver `app/views/producer/quotes/new.html.erb:44-50`). Omint exige códigos fijos de una tabla cerrada (`departureCode`: `MAA`=Argentina; `destinationCode`: `ASU`, `ARG`, `AAA`, `NAC`, `EMO`, `MAC`, `MUC`, `OCE`, `URU`).

Esto **no es un mapeo 1:1 confiable** (texto libre → enum cerrado). Necesitamos una capa de normalización:

- Un `OMINT_DESTINATION_MAP` (Hash de constante o `config/omint_destinations.yml`) que mapee strings esperables ("Europa" → `EMO`, "Estados Unidos"/"Canadá" → `NAC`, "Uruguay" → `URU`, "Brasil"/"Sudamérica" → `ASU`, etc.) usando matching case-insensitive/normalizado (quitar tildes).
- Si no hay match: la clase debe lanzar `ProviderError` (así el `QuoteResult` queda en `status: error` con el motivo en `raw_response`, en vez de reventar el job) — mismo patrón que ya maneja `ProviderQuoteJob`.
- **Recomendación a mediano plazo** (fuera de este plan, para no over-engineer ahora): si Omint termina siendo el proveedor real de referencia, vale la pena convertir `origin`/`destination` en selects con una lista cerrada de continentes/países en el wizard, en vez de texto libre — hoy el mapeo va a ser best-effort.

También hay que mapear `Quote#trip_type` (`single`/`multi_trip`/`annual`) → `productTypeCode` (`S`/`L`/`A`). `annual → A` y `single → S` son directos; `multi_trip` no tiene equivalente exacto (Omint no tiene "multiviaje" como tal — `L` es "Larga Estadía", un producto de estadía larga, no multiviaje). Propongo mapear `multi_trip → S` (cotiza los productos Simple, que cubren viajes cortos) y decidir junto al negocio si hace falta algo mejor. Marcar esto con un comentario en código señalando la ambigüedad.

## 2. Credenciales — Rails credentials, no `Provider#config`

El resto de los proveedores guardan config no sensible en `Provider#config` (json column, ver `docs/05-provider-integration.md:104-124` — **ojo**: ese doc ya advierte que el form admin de config tiene un bug que descarta el campo en silencio, hay que setear por consola/seeds). Pero `client_secret` de Omint es una credencial real de producción — no debe vivir en una columna de base de datos plana ni en seeds versionados.

```bash
bin/rails credentials:edit
```

```yaml
omint:
  client_id: "c92cbe04-c81d-428d-8c3f-453b0d45cf9e"
  client_secret: "<pedir el secret real, no el de este PDF de ejemplo si ya fue rotado>"
  token_endpoint: "https://core.omintassistance.com.ar/connect/token"
  scope: "OACoreApi IntegrationWebApi"
  agreement_number: 3329
```

`base_url` (test/prod) sí puede ir en `Provider#config` como los demás proveedores (no es secreto), para poder cambiar de ambiente sin redeploy:

```ruby
Provider.create!(
  name: "Omint Assistance",
  slug: "omint",
  status: "active", # poner "inactive" hasta validar en test
  config: {
    base_url: "https://oaapp.eastus2.cloudapp.azure.com:8448", # test; prod: https://api.omintassistance.com.ar
    timeout: 30
  }
)
```

## 3. Manejo del token (cache compartido)

El manual del PDF insiste mucho en esto: **no pedir un token por cotización**. La app corre Puma (posiblemente varios workers) + Solid Queue en proceso separado — un caché en memoria de instancia (como sugiere el ejemplo C#/Node del PDF) no se comparte entre esos procesos, así que cada uno pediría su propio token igual.

La app ya tiene `Rails.cache` disponible (Solid Cache). Usarlo como caché compartido:

```ruby
def access_token
  Rails.cache.fetch("omint:access_token", expires_in: 55.minutes) do
    fetch_new_token! # POST a token_endpoint, devuelve access_token
  end
end
```

- TTL de 55 min (contra 60 min reales) da el margen de seguridad de 5 min que pide el manual, sin necesitar lógica de expiración manual.
- `Rails.cache.fetch` con bloque ya es atómico a nivel de una sola clave para el caso normal; no hace falta mutex explícito — el peor caso (dos requests concurrentes piden token nuevo casi a la vez) es aceptable, Omint no lo prohíbe, solo pide no saturar.
- Ante un 401 al cotizar: `Rails.cache.delete("omint:access_token")`, pedir un token nuevo, reintentar **una vez** (regla explícita del manual).

## 4. Estructura de archivos (sigue el patrón existente)

```
app/services/insurance_providers/omint_provider.rb   # nuevo
config/initializers/insurance_providers.rb            # +1 línea de registro
app/jobs/provider_quote_job.rb                        # modificar para soportar Array de resultados (decisión 1.1)
db/seeds.rb                                            # +Provider omint (status: inactive hasta validar)
test/services/insurance_providers/omint_provider_test.rb
```

## 5. Esqueleto de `OmintProvider`

```ruby
module InsuranceProviders
  class OmintProvider < BaseProvider
    def self.slug = "omint"

    DESTINATION_MAP = {
      "argentina" => "ARG",
      "uruguay" => "URU",
      "europa" => "EMO",
      "estados unidos" => "NAC",
      "canada" => "NAC",
      "sudamerica" => "ASU",
      # completar con negocio — ver sección 1.2
    }.freeze

    TRIP_TYPE_MAP = { "single" => "S", "multi_trip" => "S", "annual" => "A" }.freeze

    def quote(quote)
      response = http_client.post("/Quotation/CreateQuotationB2B") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
        req.body = build_payload(quote)
      end

      raise ProviderError, response.body.to_s if response.status == 401 # manejado por retry en ProviderQuoteJob tras invalidar cache
      raise ProviderError, response.body["errors"]&.join(", ") unless response.success?

      response.body["products"].map do |product|
        {
          external_quote_id: response.body["id"],
          price_cents: (product["grossPrice"] * 100).round,
          currency: "ARS", # confirmar con Omint si el precio siempre viene en ARS
          plan_name: product["denomination"],
          provider_name: "Omint Assistance",
          valid_until: nil # el manual no informa vencimiento de la cotización en sí
        }
      end
    end

    def purchase_url(quote_result)
      # CreateQuotationB2B no emite voucher/checkout — requiere CreateComplete (manual aparte, no cubierto).
      raise NotImplementedError, "Omint requiere el flujo CreateComplete para compra, no documentado aún"
    end

    private

    def access_token
      Rails.cache.fetch("omint:access_token", expires_in: 55.minutes) { fetch_new_token! }
    end

    def fetch_new_token!
      creds = Rails.application.credentials.omint
      conn = Faraday.new(url: creds[:token_endpoint])
      res = conn.post do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(
          grant_type: "client_credentials",
          client_id: creds[:client_id],
          client_secret: creds[:client_secret],
          scope: creds[:scope]
        )
      end
      JSON.parse(res.body)["access_token"]
    end

    def build_payload(quote)
      {
        agreementNumber: Rails.application.credentials.omint[:agreement_number],
        productTypeCode: TRIP_TYPE_MAP.fetch(quote.trip_type, "S"),
        tariffTypeCode: "B",
        departureCode: "MAA", # origen fijo Argentina — confirmar si algún acuerdo cotiza desde otro país
        destinationCode: resolve_destination(quote.destination),
        dateSince: quote.departure_date.iso8601,
        dateUntil: (quote.return_date || quote.departure_date + 10.days).iso8601,
        passengerAges: quote.ages.presence || [30],
        email: quote.respond_to?(:producer) ? quote.producer&.email : nil
      }.tap { |p| p[:quantityOfDays] = 30 if p[:productTypeCode] == "A" }
    end

    def resolve_destination(destination)
      key = destination.to_s.downcase.strip
      DESTINATION_MAP[key] || raise(ProviderError, "Destino '#{destination}' sin mapeo a código Omint")
    end
  end
end
```

Notas sobre el esqueleto (para no perderlas al implementar):

- `http_client` heredado de `BaseProvider` apunta a `provider.config_for(:base_url)` — bien, ahí van test/prod.
- El manual pide reintentar UNA vez ante 401 tras renovar token. Lo más simple: dejar que `quote` levante `ProviderError` en 401, invalidar el cache del token en el `rescue`, y confiar en el `retry_on ProviderError` que ya tiene `ProviderQuoteJob` (3 intentos, 5s backoff) — pero hay que invalidar el cache de token *antes* del segundo intento o va a repetir el mismo token vencido. Ver punto 6.
- `quantityOfDays` es obligatorio solo si `productTypeCode == "A"` — hardcodeado a 30 arriba como placeholder; falta decidir si viene de algún campo del quote o si simplemente probamos con 30/45/60 y nos quedamos con uno.
- `passengerAges` — el manual exige mínimo 1 edad; `quote.ages` viene de `metadata["ages"][]` del wizard (`app/models/concerns/trip_metadata.rb:4`), confirmar que el wizard siempre la completa antes de cotizar (fallback `[30]` puesto por seguridad, revisar si tiene sentido de negocio).

## 6. Cambio necesario en `ProviderQuoteJob`

Hoy (`app/jobs/provider_quote_job.rb`):

```ruby
result = client.quote(quote)
price = Money.new(result[:price_cents], result[:currency] || Money.default_currency)
QuoteResult.create!(quote: quote, provider: provider, external_quote_id: result[:external_quote_id], raw_response: result, status: "success", price: price)
```

Propuesta — normalizar a array y crear un `QuoteResult` por elemento:

```ruby
results = Array.wrap(client.quote(quote))
results.each do |result|
  price = Money.new(result[:price_cents], result[:currency] || Money.default_currency)
  QuoteResult.create!(
    quote: quote, provider: provider,
    external_quote_id: result[:external_quote_id],
    raw_response: result, status: "success", price: price
  )
end
```

`Array.wrap` deja intactos a todos los providers existentes (devuelven un Hash → queda envuelto en un array de 1). Es el único cambio necesario en el job para soportar 1.1-B.

## 7. Manejo de errores (mapeo directo del manual)

| HTTP | Causa | Acción en `OmintProvider` |
|---|---|---|
| 400 | Body inválido / código no encontrado | `raise ProviderError` con el mensaje de `errors[]` — termina en `QuoteResult status: error`, no reintenta (no es transitorio) |
| 401 | Token expirado/inválido | Invalidar `Rails.cache` del token, `raise ProviderError` → el `retry_on` de `ProviderQuoteJob` reintenta con token nuevo |
| 403 | Integración deshabilitada / acuerdo ajeno | `raise ProviderError` — no reintentar automáticamente tiene sentido, pero el job ya limita a 3 intentos con backoff, no rompe nada dejar que reintente igual |
| 5xx | Backend caído | Cubierto por el `retry_on ... wait: 5.seconds, attempts: 3` ya existente |

## 8. Plan de pruebas antes de producción

1. Unit test del `OmintProvider` con `webmock` (no está en el Gemfile — agregarlo, ver `docs/05-provider-integration.md:218`) stubbeando `connect/token` y `CreateQuotationB2B`, cubriendo: token cacheado (segunda llamada no pega a `/connect/token`), array de productos → array de hashes, 400 → `ProviderError`, 401 → invalida cache y reintenta.
2. Seed con `status: "inactive"` primero; activar manualmente en un `Company` de prueba (o vía consola) y correr una cotización real contra el ambiente de **test** (`oaapp.eastus2...`) desde `/producer/quotes/new`.
3. Confirmar visualmente en `producer/quotes/show` que aparecen varios `QuoteResult` de Omint (uno por producto) sin romper el layout pensado para "un resultado por proveedor".
4. Validar mapeo de destino con al menos: Argentina, Europa, Uruguay, y un destino sin mapeo (debe fallar prolijo, no explotar el job).
5. Recién ahí, cambiar `base_url` a producción y `status: "active"`.

## 9. Fuera de alcance de este plan

- **Compra/emisión** (`CreateComplete`) — el manual aclara que `CreateQuotationB2B` no emite voucher. Ese es un endpoint/manual distinto; `purchase_url` queda con `NotImplementedError` explícito hasta tener ese manual.
- Webhook de Omint (`parse_webhook`/`valid_webhook?`) — no hay info en este PDF sobre si Omint notifica por webhook o si la emisión es síncrona vía `CreateComplete`. Definir cuando llegue ese manual.
