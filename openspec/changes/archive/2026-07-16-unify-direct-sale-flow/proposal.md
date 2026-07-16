## Why

Ruka vende seguros de viaje directamente en ruka.com (venta "de la casa", sin producer afiliado de por medio) y hoy ese flujo se arma con dos motores de cotización distintos y dos caminos de compra distintos que no comparten código con el flujo del producer. El camino de compra directa (`Public::LandingController#checkout`) nunca emite un registro `Policy` real — solo actualiza `Quote.metadata` con un JSON — así que hoy no existe una fuente de verdad confiable de qué se vendió directo. Antes de construir el link de producer y las comisiones (fase futura, fuera de este change), Ruka necesita que la venta directa sea un flujo único, correcto y trazable de punta a punta: cotizar → comparar → comprar → emitir `Policy`.

## What Changes

- Unificar los dos motores de cotización (`QuoteSearchService` síncrono usado por la landing pública vs `QuoteJob`/`ProviderQuoteJob` asíncrono usado por el producer) en un solo motor de cotización, reutilizado por ambos flujos de entrada (landing pública y `/producer`).
- Corregir el bug de `Public::LandingController#persist_results`, que marca `Quote.status = "quoted"` incondicionalmente aunque no haya ningún `QuoteResult` exitoso.
- **BREAKING**: eliminar el camino de compra que persiste la compra únicamente en `Quote.metadata` (`Public::LandingController#checkout` / `complete_purchase!`). Toda compra —incluida la venta directa en ruka.com— debe terminar creando un registro `Policy` real, de la misma forma que ya lo hace `WebhookProcessorJob` para el flujo del producer.
- Agregar a `Policy` (o a `Quote`) un campo de canal/atribución que distinga "emitido directo por Ruka" de "emitido vía producer", dejando la base preparada para la fase de comisiones sin calcular ni mostrar comisión todavía.
- Dejar documentada en `design.md` la tensión entre el modelo de multi-tenancy actual (`acts_as_tenant :company`, pensado para múltiples agencias aisladas) y el modelo de negocio real (una sola Ruka con N producers afiliados compartiendo catálogo), sin resolverla en este change.
- Fuera de alcance de este change: integración real con proveedores de seguros (los providers siguen siendo simulados: `AssistCardFake`, `TravelAceFake`, `UniversalAssistanceFake`, `ExampleProvider`), el link propio de cada producer (`ruka.com/:producer_slug`), y el cálculo/pantalla de comisiones.

## Capabilities

### New Capabilities
- `direct-sale-flow`: cotización, comparación, compra y emisión de póliza para la venta directa de Ruka en ruka.com (sin producer afiliado), incluyendo el motor de cotización unificado y la trazabilidad de canal en `Policy`.

### Modified Capabilities
(No hay specs existentes en `openspec/specs/` todavía — este es el primer capability documentado del sistema.)

## Impact

- **Código afectado**: `app/services/quote_search_service.rb`, `app/services/insurance_providers/*`, `app/jobs/quote_job.rb`, `app/jobs/provider_quote_job.rb`, `app/controllers/public/landing_controller.rb`, `app/controllers/producer/quotes_controller.rb`, `app/controllers/webhooks_controller.rb`, `app/jobs/webhook_processor_job.rb`, `app/models/quote.rb`, `app/models/quote_result.rb`, `app/models/policy.rb`.
- **Schema**: probable migración para agregar el campo de canal/atribución en `policies` (o `quotes`); sin cambios de multi-tenancy en este change.
- **Sin impacto** en `/admin/*` más allá de que `Policy` gane un campo nuevo (el filtrado/listado admin de "nuestro vs producer" queda fuera de alcance explícito de este change, ya que hoy no hay producers reales vendiendo por link propio).
