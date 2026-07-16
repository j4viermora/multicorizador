## Context

Ruka corre hoy dos caminos independientes para lo mismo (cotizar y comprar), según de dónde entra el usuario:

- **Producer** (`/producer/*`, autenticado): `Producer::QuotesController#create` → `QuoteJob.perform_later` → `ProviderQuoteJob` por cada `Provider.active` (async, `retry_on ProviderError`, persiste `QuoteResult` con `status: success|error`, y marca `Quote` como `quoted` recién cuando no quedan resultados `pending`). La compra se completa vía `WebhooksController` → `WebhookProcessorJob` → `Policy.create!` idempotente por `policy_number`.
- **Landing pública** (`ruka.com`, sin auth): `Public::LandingController#create` → `QuoteSearchService` (sync, en el mismo request, sin reintentos, descarta errores del array de resultados) → persiste solo los `QuoteResult` exitosos y marca `Quote` como `quoted` **incondicionalmente** (bug: incluso si `@results` vino vacío). La compra (`#checkout` → `complete_purchase!`) solo crea un `Traveler` y mete todo en `Quote.metadata` (JSON) — nunca crea `Policy`.

Confirmado con el dueño del producto: Ruka es la casa, y "venta directa" (ruka.com sin producer) es 100% ingreso de Ruka. El link de producer (`ruka.com/:producer_slug`) y el cálculo de comisión (mix producer × proveedor, calculado al emitir la `Policy`, no al cotizar) son fase futura, explícitamente fuera de este change. Este change solo necesita dejar la venta directa cotizando y comprando de forma única y correcta, y dejar en `Policy` un dato de canal para que la fase de comisiones no tenga que hacer backfill.

## Goals / Non-Goals

**Goals:**
- Un solo motor de cotización, usado tanto por `/producer` como por la landing pública.
- Toda compra (incluida la directa) termina en un `Policy` real — eliminar el camino que solo escribe en `Quote.metadata`.
- `Quote.status` refleja la realidad: no pasa a `quoted` si no hay al menos un `QuoteResult` exitoso.
- `Policy` (o `Quote`) puede responder "¿esto se vendió directo por Ruka?" sin ambigüedad, aunque hoy la respuesta sea siempre "sí" en la práctica.

**Non-Goals:**
- Integrar proveedores reales vía HTTP (siguen siendo `AssistCardFake`, `TravelAceFake`, `UniversalAssistanceFake`, `ExampleProvider`).
- Implementar el link de producer (`ruka.com/:producer_slug`) o cualquier lógica de atribución de referidos.
- Calcular o mostrar comisiones.
- Resolver la tensión de multi-tenancy descrita abajo — solo se documenta.

## Decisions

### 1. Motor de cotización único: adaptar el camino async (`QuoteJob`/`ProviderQuoteJob`) como motor común
`QuoteSearchService` se elimina como camino de compra separado. La landing pública pasa a usar el mismo `QuoteJob`/`ProviderQuoteJob` que usa `/producer`, contra un `Quote` ya persistido (igual que hace `Producer::QuotesController#create` hoy).

**Por qué esta dirección y no la inversa** (llevar todo a síncrono tipo `QuoteSearchService`): el motor async ya tiene reintentos (`retry_on ProviderError`), ya persiste separadamente los `QuoteResult` con `status: error` (visibilidad real de qué proveedor falló), y ya es el que alimenta el flujo de producer que termina en `Policy` real vía webhook. Duplicar esa robustez en un motor síncrono es más trabajo que adaptar la landing a usar jobs.

**Alternativas consideradas:**
- Mantener ambos motores pero compartir la lógica de "llamar a un provider" (extraer un objeto común invocado por los dos). Se descarta: no resuelve la inconsistencia de estados (`Quote` marcado `quoted` sin resultados) ni el hecho de que la landing nunca emite `Policy`; solo reduce duplicación de código, no la duplicación de comportamiento.
- Hacer todo síncrono (llevar `/producer` a `QuoteSearchService`). Se descarta: pierde reintentos y tracking de errores por `QuoteResult`, que ya están probados en producción vía el flujo de producer.

**Implicancia de UX**: la landing pública deja de responder resultados en el mismo request (`render :results` inmediato) y pasa a un patrón de polling/Turbo Stream esperando a que `QuoteJob` complete (igual que ya debería pasar, conceptualmente, en `/producer`). Esto es un cambio de experiencia visible que hay que resolver en `tasks.md` (pantalla de "buscando cotizaciones..." con actualización cuando `Quote.status` pasa a `quoted`).

### 2. Toda compra crea un `Policy` real
Se elimina `Public::LandingController#complete_purchase!` tal como está (solo `Traveler` + `Quote.metadata`). El checkout de la venta directa pasa a crear el `Policy` directamente (sin depender de un webhook externo, porque no hay proveedor real emitiendo nada) usando los mismos campos que hoy llena `WebhookProcessorJob` (`policy_number`, `issued_at`, `starts_at`, `ends_at`, `premium`, `total`), generando esos valores localmente ya que el proveedor es simulado.

**Alternativa considerada**: simular también un webhook entrante (el checkout dispara un webhook fake hacia sí mismo para reusar `WebhookProcessorJob`). Se descarta por indirecto y frágil — agrega una vuelta HTTP innecesaria para simular algo que puede ser una llamada directa a un service/`Policy.create!`. Se prefiere extraer la lógica de creación de `Policy` de `WebhookProcessorJob` a un service compartido (p. ej. `PolicyIssuer` o similar — nombre final se define en tasks/implementación) invocado tanto por el webhook real como por el checkout directo.

### 3. Campo de canal en `Policy`
Se agrega un campo (p. ej. `sold_via` o `channel`, string/enum: `"direct"` por ahora, dejando espacio para `"producer"` en la fase futura) en `policies`. Vive en `Policy` y no en `Quote`, porque `Policy` es el evento de negocio real (lo que genera ingreso/comisión); `Quote` puede tener múltiples intentos de compra fallidos que no deberían "contar" para atribución.

**Alternativa considerada**: derivar el canal indirectamente de `Quote.producer` (si el producer es un usuario "house" fijo, es directo; si no, es de producer). Se descarta: acopla la semántica de negocio a un dato de infraestructura (quién es el producer asignado), que además hoy siempre existe por default (`resolve_producer` cae a un producer por defecto aunque no haya `ref`). Un campo explícito es más barato de mantener correcto que inferirlo.

### 4. Tensión de multi-tenancy (documentada, no resuelta en este change)
El modelo actual asume múltiples `Company` aisladas (`acts_as_tenant :company` sobre `Quote`, `Traveler`, `Link`, `QuoteResult`, `Policy`, `User`). El modelo de negocio real es una sola Ruka con N producers afiliados compartiendo el mismo catálogo de providers — no agencias aisladas. Este change no toca `acts_as_tenant` ni el modelo `Company`; la venta directa sigue operando dentro del tenant que hoy resuelve `LandingController` (compañía "ruka", vía `RUKA_DIRECT_SLUG`). **Riesgo dejado explícito para la fase de link de producer**: cuando se implemente `ruka.com/:producer_slug`, habrá que decidir si el slug vive en `User` (rompiendo la asunción de que el productor pertenece a una única `Company` aislada) o si se mantiene el esquema de `Company` + `ref` actual. No se toma esa decisión acá.

## Risks / Trade-offs

- [Cambiar la landing de síncrono a async cambia la UX de "resultado inmediato" a "esperar resultados"] → Mitigación: usar Turbo Streams para que la espera sea fluida (la infraestructura Hotwire ya está en el stack); documentar el estado de carga en tasks.md.
- [Extraer la creación de `Policy` a un service compartido entre webhook y checkout directo puede introducir una regresión en el flujo de producer si no se replica el comportamiento idempotente (`return if Policy.exists?(policy_number: ...)`)] → Mitigación: cubrir con tests de integración ambos caminos (webhook y checkout directo) contra el mismo service antes de eliminar el código viejo.
- [Quitar `QuoteSearchService` puede tener referencias que no se detectaron en la exploración inicial (vistas, otros controllers)] → Mitigación: grep exhaustivo de `QuoteSearchService` y `QuoteSearch` antes de eliminar, parte de las tasks.
- [El campo de canal en `Policy` sin caso de uso real todavía (siempre `"direct"`) puede quedar mal diseñado y requerir otra migración en la fase de producer] → Mitigación: modelarlo como string/enum simple y documentar en el comentario de la migración que los valores futuros incluirán `"producer"`, sin comprometerse a la forma final del modelo de comisión.

## Migration Plan

1. Migración de schema: agregar columna de canal a `policies` (default `"direct"`, no nula).
2. Extraer la lógica de creación de `Policy` desde `WebhookProcessorJob` a un service compartido; `WebhookProcessorJob` pasa a invocarlo (comportamiento del flujo de producer no cambia).
3. Adaptar `Public::LandingController` para: (a) persistir el `Quote` y disparar `QuoteJob` en vez de `QuoteSearchService`; (b) mostrar estado de espera hasta que el `Quote` pase a `quoted`; (c) en `#checkout`, invocar el service de emisión de `Policy` en vez de `complete_purchase!`.
4. Corregir `Quote.status` para no pasar a `quoted` sin al menos un `QuoteResult` exitoso (aplica tanto al camino unificado como remanente de `ProviderQuoteJob#check_all_results_complete`, que ya lo hace bien — verificar que la landing herede ese mismo comportamiento al unificarse).
5. Eliminar `QuoteSearchService` y el código muerto de `complete_purchase!` una vez migrados los dos puntos anteriores.
6. Rollback: si algo falla en producción, revertir el deploy (no hay dato irreversible migrado — la columna nueva es aditiva y con default seguro).

## Open Questions

- ¿El nombre final del campo de canal en `Policy` es `sold_via`, `channel`, `origin` u otro? (se define en implementación, no bloquea el diseño)
- ¿La espera de resultados en la landing pública se resuelve con Turbo Streams (recomendado, ya está en el stack) o con polling simple? Definir en tasks.md al implementar la UI.
- ¿Cómo se van a testear los flujos de venta directa? Minitest de integración cubriendo cotizar → comparar → comprar → `Policy` creada, tanto para el flujo de producer (regresión) como para la landing (nuevo).
