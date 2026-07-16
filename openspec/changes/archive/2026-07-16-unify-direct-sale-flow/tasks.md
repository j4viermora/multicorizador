## 1. Schema

- [x] 1.1 Migración: agregar columna de canal/atribución a `policies` (string, `null: false`, default `"direct"`), Postgres-portable (DSL estándar, `add_index` si se filtra por esta columna en admin).
- [x] 1.2 Actualizar `db/schema.rb` con `bin/rails db:migrate` y confirmar que replica limpio en una DB nueva.

## 2. Servicio compartido de emisión de póliza

- [x] 2.1 Extraer de `WebhookProcessorJob` la lógica de construcción/creación de `Policy` (incluida la idempotencia por `policy_number`) a un service compartido, invocado con los datos ya resueltos (quote_result, datos de póliza, canal).
- [x] 2.2 Adaptar `WebhookProcessorJob` para usar el nuevo service, preservando el comportamiento actual (test de regresión: mismo webhook, misma `Policy` creada, mismo `Quote.status = "purchased"`).
- [x] 2.3 Test: llamar dos veces al service con el mismo `policy_number` no crea una `Policy` duplicada.

## 3. Motor de cotización único

- [x] 3.1 Adaptar `Public::LandingController#create` para persistir el `Quote` (como hoy hace `persist_search`) y encolar `QuoteJob.perform_later(quote.id)` en vez de invocar `QuoteSearchService` de forma síncrona.
- [x] 3.2 Confirmar que `QuoteJob`/`ProviderQuoteJob` funcionan correctamente para un `Quote` creado desde la landing pública (sin producer autenticado) — revisar cualquier asunción de `current_user`/tenant que solo aplicaba al flujo `/producer`. (Se encontró y corrigió un bug real: `Quote` no tenía `trip_days`/`max_age`, que los providers fake necesitan — se extrajo el concern `TripMetadata`, compartido con el mismo cálculo que antes solo tenía `QuoteSearch`.)
- [x] 3.3 Verificar/ajustar `ProviderQuoteJob#check_all_results_complete` para que el `Quote` NO pase a `quoted` si ningún `QuoteResult` fue exitoso (cubre el bug de `persist_results` marcando `quoted` incondicionalmente). Se agregó el estado `no_results` al enum de `Quote`.
- [x] 3.4 Eliminar `app/services/quote_search_service.rb` y sus referencias (grep exhaustivo de `QuoteSearchService` en app/, test/, views).
- [x] 3.5 Test de integración: cotización desde la landing pública crea `Quote`, encola `QuoteJob`, y tras ejecutar los jobs el `Quote` queda `quoted` con `QuoteResult`s persistidos (éxitos y errores).
- [x] 3.6 Test: si todos los providers fallan, el `Quote` no queda en `quoted`.

## 4. UI de espera en la landing pública

- [x] 4.1 Reemplazar el `render :results` inmediato de `Public::LandingController#create` por una vista de espera ("buscando cotizaciones...") que se actualiza cuando el `Quote` pasa a `quoted` (Turbo Streams, siguiendo el stack Hotwire ya usado en el resto de la app). Nueva ruta GET `cotizar/:slug/resultados/:token` (`public_landing_results_path`), acción `#results`, con `turbo_stream_from` + broadcast desde `Quote#broadcast_status_update`.
- [x] 4.2 Ajustar `app/javascript/controllers/quote_wizard_controller.js` si depende del flujo síncrono anterior. (No depende — es solo el wizard de pasos del formulario de búsqueda, sin cambios necesarios.)
- [x] 4.3 Vista de resultados (`:results` o equivalente) lee `QuoteResult.successful` del `Quote` ya persistido, igual que hoy hace `Producer::QuotesController#show`. Implementado en `_quote_status.html.erb`.

## 5. Compra directa emite póliza real

- [x] 5.1 Reemplazar `Public::LandingController#complete_purchase!` (que hoy solo crea `Traveler` + actualiza `Quote.metadata`) para que invoque el service de emisión de póliza de la tarea 2.1, generando los datos de póliza localmente (ya que los providers son simulados: `policy_number`, `issued_at`, `starts_at`, `ends_at`, `premium`, `total`).
- [x] 5.2 El `Policy` creado en este camino queda con canal `"direct"` (columna de la tarea 1.1).
- [x] 5.3 `Quote.status` pasa a `"purchased"` solo después de que el `Policy` fue creado exitosamente (no antes) — delegado a `PolicyIssuer`, que hace `quote.update!(status: "purchased")` solo tras `Policy.create!`.
- [x] 5.4 Test de integración: checkout completo en la landing pública (cotizar → elegir plan → checkout) termina con un `Policy` real persistido, canal `"direct"`, y `Quote.status == "purchased"`.
- [x] 5.5 Confirmar que `Traveler` sigue creándose con los mismos datos que hoy (no se pierde información del pasajero al migrar el camino de compra).

## 6. Limpieza y regresión

- [x] 6.1 Grep final de `QuoteSearch` (el ActiveModel) y `complete_purchase!` para confirmar que no quedan referencias muertas o rutas/vistas huérfanas.
- [x] 6.2 Correr toda la suite (`bin/rails test`) y `bin/rubocop`; confirmar que el flujo de `/producer` (cotizar y comprar vía webhook) sigue pasando sin cambios de comportamiento. (Se agregaron fixtures reales — `companies.yml`/`users.yml` estaban rotas/vacías desde el scaffold inicial — y tests de regresión para el webhook.)
- [x] 6.3 `bin/brakeman` — confirmar que el service compartido de emisión de póliza no introduce nuevos hallazgos. (`--ensure-latest` de `bin/brakeman` falla sin red en este entorno; `bundle exec brakeman` directo: 0 warnings, 0 errors.)
- [x] 6.4 Prueba manual end-to-end en `bin/dev`: cotizar en `ruka.com`, comparar resultados, comprar, verificar `Policy` en `/admin` (o consola) con canal `"direct"`. Verificado con `bin/dev` real (Puma + Solid Queue worker): POST de cotización → redirect a `/cotizar/ruka/resultados/:token` → los 4 providers fake respondieron vía `QuoteJob`/`ProviderQuoteJob` → `Quote` pasó a `quoted` → checkout creó `Policy` real (`sold_via: "direct"`) y `Quote` pasó a `purchased`. Datos de prueba limpiados de la DB de desarrollo al terminar.
