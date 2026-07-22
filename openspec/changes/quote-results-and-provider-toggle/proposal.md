## Why

El buscador de una sola pantalla ya cotiza contra tres proveedores fake, pero el flujo se empobrece al llegar a los resultados: la vista de comparación descarta casi todo lo que los proveedores devuelven. Cada fake entrega ocho coberturas y ninguna se muestra; los resultados no se ordenan por precio; el controlador filtra con `.successful`, así que un proveedor que falla desaparece sin dejar rastro; y el botón "Seleccionar" apunta a `"#"`. Comparar es el producto, y hoy la pantalla que compara es la más pobre del sistema.

En paralelo, Omint quedó integrado pero sembrado como `inactive` a propósito (`db/seeds.rb:87`, commit `fa4c3c8`), a la espera de validación contra el ambiente de test. La palanca funciona — `QuoteJob` solo itera `Provider.active` — pero prenderla exige entrar al form de edición y pasar por un textarea con el JSON crudo de `config`, donde un error de tipeo rompe el `CHECK (json_valid)`. Un super admin no debería arriesgar la configuración de un proveedor solo para encenderlo.

## What Changes

**Comparación de resultados (`/producer/quotes/:id`)**

- **Una fila por proveedor, con sus opciones de plan en esa fila.** El productor compara horizontalmente entre planes del mismo proveedor y verticalmente entre proveedores. Cada fake pasa a devolver cuatro niveles de plan en vez de uno.
- Rediseño de la pantalla de resultados en Flowbite, alineada al lenguaje visual del buscador de una sola pantalla (paleta `teal`, iconos Tabler).
- Se muestran las coberturas que hoy se descartan: cada opción expone el detalle que el proveedor devuelve en `raw_response["coverage"]`, no solo precio y nombre de plan.
- Los resultados con `status: "error"` dejan de ser invisibles: `Producer::QuotesController#show` filtra hoy con `.successful`, así que un proveedor caído desaparece sin explicación.
- El estado `quoting` muestra los resultados parciales que ya llegaron en vez de esperar a que respondan todos.

**Administración de proveedores (`/admin/providers`)**

- Toggle de activación directo en el listado, sin pasar por el form de edición ni tocar `config`.
- El listado indica qué proveedores participan de una cotización, para que el efecto del toggle sea legible antes de cotizar.
- Ajuste visual de `index` y `edit` para alinearlas al resto del admin. Las vistas **no** están rotas: las clases que usan (`table-zebra`, `badge-success`, `btn-ghost`, `textarea`, `label-text`) están definidas con `@apply` en `app/assets/tailwind/application.css`. El trabajo aquí es acomodar el toggle, no reparar estilos.

**Proveedores fake**

- Cada fake pasa a devolver una escala de cuatro planes (de básico a premium) con precios y coberturas crecientes, en lugar del plan único actual. No se crean proveedores nuevos: `AssistCardFake`, `UniversalAssistanceFake` y `TravelAceFake` ya existen, están registrados y se siembran activos por el `default: "active"` de la columna.
- Sin cambios en `ProviderQuoteJob` ni en el esquema: el job ya hace `Array.wrap(client.quote(quote))` y crea un `QuoteResult` por elemento, así que devolver un array de cuatro ya produce cuatro filas.

## Capabilities

### New Capabilities

- `quote-results-comparison`: cómo se presentan y comparan los resultados de cotización — agrupación por proveedor, orden de las opciones dentro de cada fila, coberturas visibles y estados parciales (cotizando, error de proveedor, sin resultados).
- `provider-plan-tiers`: el contrato por el cual un proveedor devuelve múltiples opciones de plan para una misma búsqueda, y cómo los fakes lo materializan.
- `provider-activation`: control de qué proveedores participan de una cotización, incluyendo la activación/desactivación por parte de un super admin y su efecto sobre el fan-out de `QuoteJob`.

### Modified Capabilities

Ninguna. `direct-sale-flow` y `admin-policy-visibility` no cambian sus requisitos: el rediseño ocurre aguas abajo del fan-out y el toggle no altera el ciclo de vida de la cotización.

## Impact

**Proveedores**
- `app/services/insurance_providers/{assist_card_fake,universal_assistance_fake,travel_ace_fake}.rb` — `#quote` pasa de devolver un hash a devolver un array de cuatro.
- `BaseProvider#quote` — documentar que el retorno puede ser un hash o un array de hashes, contrato que `ProviderQuoteJob` ya honra pero que hoy no está escrito en ningún lado.

**Vistas**
- `app/views/producer/quotes/show.html.erb` — rediseño completo, agrupado por proveedor.
- `app/views/admin/providers/index.html.erb` — suma el toggle en cada fila.
- `app/views/public/quotes/show.html.erb` — a revisar por consistencia; muestra los mismos resultados al cliente final.

**Controladores y rutas**
- `Admin::ProvidersController` — nueva acción de miembro para el toggle; `config/routes.rb:10` pasa de `resources :providers` a un bloque con `member`.
- `Producer::QuotesController#show:10` — hoy `@quote.quote_results.successful`, sin orden y descartando errores; debe exponer ambos conjuntos y ordenar por precio.
- El botón "Seleccionar" apunta hoy a `"#"`. Este cambio **no** implementa la selección de un resultado; la deja explícitamente pendiente para no arrastrar el flujo de compra al alcance.

**Sin cambios de esquema.** `providers.status` (string, `default: "active"`) y `quote_results.status` (enum `pending`/`success`/`error`) ya soportan todo lo anterior. `raw_response` ya trae las coberturas y está casteado con `attribute :raw_response, :json`.

**Sin cambios en la integración de Omint.** El proveedor sigue sembrado `inactive` con su `client_secret` desde `ENV["OMINT_CLIENT_SECRET"]`; este cambio solo hace que encenderlo sea seguro y de un clic. La validación contra el ambiente de test de Omint queda fuera de alcance.

**Tests**
- Test de sistema del flujo completo: cotizar contra los tres fakes y verificar la comparación.
- Test de controlador del toggle, incluyendo que un `producer` no pueda invocarlo.
- `test/services/insurance_providers/omint_provider_test.rb` no se toca.
