## Why

Cotizar cuesta ~7,3 segundos con cuatro proveedores fake, y ese número sale de latencias simuladas conservadoras (3s, 4s y 6s). Con seis APIs reales y `threads: 3` en `config/queue.yml`, el fan-out entra en dos tandas y el tiempo crece. Hoy cada búsqueda paga ese costo completo, incluso cuando es idéntica a una que se resolvió hace dos minutos: un productor que corrige un dato y vuelve, o dos clientes de la misma agencia consultando el mismo destino, disparan el mismo trabajo desde cero.

Cachear resultados de cotización es práctica común en agregadores de viajes, pero tiene un filo: un precio vencido que se muestra como vigente termina en una póliza emitida a un precio que el proveedor ya no honra, y la diferencia la absorbe la agencia. Ese riesgo **ya existe hoy sin caché**: `Public::LandingController#complete_purchase!` toma el `QuoteResult` por id y emite con su precio sin mirar vigencia en ningún momento. El caché ensancha esa ventana, así que la validación es su contraparte necesaria y no una mejora separada.

## What Changes

**Reutilización de búsquedas equivalentes**

- Una cotización nueva cuyos parámetros coinciden con los de una búsqueda reciente del mismo tenant reutiliza aquellos resultados en lugar de volver a llamar a los proveedores.
- La equivalencia se calcula sobre los parámetros normalizados que **efectivamente mueven el precio**: origen, destino, fecha de salida, fecha de regreso, tipo de viaje, cantidad de viajeros y **las edades**. Las edades son parte de la clave porque los proveedores aplican recargo por edad — dos búsquedas de dos pasajeros con edades 30/30 y 30/70 no son la misma búsqueda.
- El alcance es **por empresa**. Una entrada de caché nunca se comparte entre tenants: cada `Company` tiene su moneda, y a futuro podría tener márgenes propios.
- Los resultados en `error` no se reutilizan. Un proveedor caído treinta segundos no puede quedar caído en el caché durante horas.

**Vigencia**

- Cada `QuoteResult` registra hasta cuándo es válido. Los proveedores que informan `valid_until` fijan ese límite; **Omint no lo informa**, así que hace falta un valor por defecto configurable en lugar de depender del dato del proveedor.
- Una entrada vencida no se reutiliza aunque esté dentro de la ventana del caché.
- **BREAKING (comportamiento):** el checkout deja de emitir pólizas sobre resultados vencidos. Hoy lo permite; después de este cambio, una compra sobre una cotización expirada se rechaza y se ofrece recotizar.

**Observabilidad**

- Queda registrado si una cotización se resolvió con proveedores o reutilizando una búsqueda previa, para poder medir el ahorro real en lugar de suponerlo.

## Capabilities

### New Capabilities

- `quote-search-cache`: cuándo dos búsquedas se consideran equivalentes, qué se reutiliza y qué no, y el alcance por tenant.
- `quote-result-expiry`: la vigencia de un resultado de cotización y su efecto sobre la reutilización y sobre la emisión de pólizas.

### Modified Capabilities

Ninguna. `quote-results-comparison` sigue mostrando lo mismo con la misma agrupación: los resultados reutilizados son `QuoteResult` normales. `provider-plan-tiers` y `provider-activation` no cambian.

## Impact

**Esquema**
- `quotes` suma `search_fingerprint` (string, indexado junto a `company_id`) y un registro de si se resolvió desde caché.
- `quote_results` suma `valid_until` (datetime). Hoy el dato solo existe dentro del JSON `raw_response` de algunos proveedores, donde no se puede filtrar en SQL.

**Código**
- `Quote` — cálculo y normalización del fingerprint.
- `QuoteJob` — antes de encolar, busca una búsqueda equivalente reciente y vigente.
- `ProviderQuoteJob` — persiste `valid_until` al crear cada resultado.
- `Public::LandingController#complete_purchase!:82` — valida vigencia antes de llamar a `PolicyIssuer`.
- `WebhookProcessorJob:15` es el otro punto que emite pólizas, pero **no** valida vigencia: llega desde el proveedor confirmando una compra ya concretada, así que rechazarla ahí perdería una venta real.

**Sin cambios en la comparación ni en los proveedores.** Los service objects de `app/services/insurance_providers/` no se tocan; el caché opera aguas arriba del fan-out.

**Riesgo principal:** `external_quote_id` es el identificador de la cotización ante el proveedor. Reutilizar resultados implica reutilizar esos identificadores, y un proveedor real puede rechazarlos al comprar aunque el precio siga vigente. Por eso el caché sirve para **mostrar**, y la compra debe revalidar contra el proveedor — alcance que este change delimita explícitamente en su design.
