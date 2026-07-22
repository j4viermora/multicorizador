## Context

El fan-out de cotización ya funciona end-to-end: `QuoteJob` itera `Provider.active` y encola un `ProviderQuoteJob` por proveedor, que crea un `QuoteResult`. Tres proveedores fake (`AssistCardFake`, `UniversalAssistanceFake`, `TravelAceFake`) devuelven precios derivados de días de viaje, cantidad de viajeros y un recargo para 65+, más una lista de ocho coberturas cada uno. Todo eso ya está sembrado y activo.

El problema está en la última milla. `Producer::QuotesController#show:10` hace `@quote_results = @quote.quote_results.successful`: sin ordenar, y descartando los resultados en `error`. La vista muestra por resultado el nombre del proveedor, el `plan_name` y el precio — las ocho coberturas que el proveedor devolvió en `raw_response` nunca se renderizan. El botón "Seleccionar" apunta a `"#"`.

Restricción de estilo relevante: el proyecto tiene un `@layer components` en `app/assets/tailwind/application.css` con `.card`, `.badge`, `.table`, `.alert`, `.btn` y variantes, construidas con `@apply` en el lenguaje de Flowbite. Los nombres se parecen a DaisyUI porque la migración conservó el vocabulario deliberadamente; son clases propias del proyecto y hay que reutilizarlas, no reemplazarlas.

## Goals / Non-Goals

**Goals:**

- Que la pantalla de comparación muestre lo que los proveedores efectivamente devuelven: coberturas, no solo precio.
- Que el productor pueda contrastar coberturas equivalentes entre proveedores, no solo leer tres tarjetas independientes.
- Que un proveedor que falla sea visible en lugar de desaparecer.
- Que un super admin pueda encender o apagar un proveedor de un clic, sin arriesgar su `config`.

**Non-Goals:**

- **Implementar la selección de un resultado.** El botón "Seleccionar" seguirá sin destino funcional; conectarlo arrastra el flujo de compra (`pending_payment`, `purchase_url`, emisión de póliza) a este cambio.
- **Validar Omint contra su ambiente de test.** El toggle hace que encenderlo sea seguro; probar que la integración responde bien es otro trabajo.
- **Normalizar coberturas entre proveedores.** Cada uno nombra las suyas a su manera; la comparación fila a fila exacta requiere un diccionario de equivalencias que hoy no existe.
- **Refactorizar el fan-out o los jobs.** El contrato de `QuoteJob` se preserva tal cual.

## Decisions

### Comparación: una fila por proveedor, sus opciones de plan dentro de la fila

El layout es una fila por proveedor, y dentro de cada fila las opciones de plan de ese proveedor ordenadas de más económica a más cara. El productor lee horizontalmente la escala de un proveedor y verticalmente el mismo escalón entre proveedores.

Esto esquiva el problema que hacía inviable la tabla comparativa clásica (proveedores en columnas, coberturas en filas): esa tabla exige que las coberturas de proveedores distintos sean alineables, y no lo son — cada uno usa su propia nomenclatura (`"Asistencia médica"`, `"Condiciones preexistentes"`) sin clave estable que las vincule, así que una tabla armada por nombre coincidente produciría filas fantasma con el primer proveedor real. Dentro de un mismo proveedor, en cambio, los planes **sí** son comparables entre sí: comparten nomenclatura por construcción. El layout por filas pone la comparación exacta donde es confiable y deja la comparación entre proveedores en el plano aproximado, que es lo que honestamente se puede afirmar hoy.

Alternativa considerada: mostrar solo las 3-4 coberturas principales de cada opción y ocultar el resto. Decidir cuáles son "principales" es otra forma del problema de normalización, así que se muestran todas.

### El número de opciones por proveedor no se hardcodea

La pantalla se diseña para cuatro opciones por fila porque es lo que van a devolver los fakes, pero el layout no asume ese número. Un proveedor real puede devolver dos, o siete, y la fila debe seguir funcionando — el spec lo exige explícitamente. La consecuencia práctica es que la fila es un contenedor que fluye (scroll horizontal contenido o wrap), no una grilla de cuatro columnas fijas.

Esto también evita el caso feo de una fila con una sola opción dejando tres huecos vacíos.

### El agrupamiento y el orden viven en el controlador, no en la vista

`Producer::QuotesController#show` pasa a entregar los resultados exitosos ya agrupados por proveedor, con las opciones de cada grupo ordenadas por `price_cents` ascendente y los grupos ordenados por el precio mínimo de cada uno. Resolverlo en la vista con `group_by` + `sort_by` funcionaría, pero es el contrato de la pantalla (el spec lo exige en tres requisitos) y pertenece a donde se arma el conjunto de datos, donde además es testeable sin renderizar.

Cargar los resultados con `includes(:provider)` para que el agrupamiento no dispare una consulta por resultado — con tres proveedores × cuatro opciones son doce.

Los resultados en `error` se exponen aparte: un resultado fallido no tiene precio con el cual ordenarse, y su unidad de presentación es el proveedor, no la opción. La vista los presenta después de las filas exitosas.

### Los fakes generan la escala derivándola de su tarifa base

Cada fake ya calcula un precio a partir de tarifa diaria × días × viajeros × recargo por edad. La escala de cuatro planes se construye aplicando multiplicadores sobre ese cálculo (el plan base conserva el precio actual, los superiores lo escalan) y sumando o ampliando coberturas en cada escalón.

Se prefiere derivar sobre inventar cuatro tablas de precios independientes: mantiene el comportamiento ya verificado frente a días, viajeros y edad — que el spec exige preservar en toda la escala — y hace que agregar un escalón sea una línea, no una tabla nueva.

### El toggle es una acción de miembro dedicada, no un `update` parcial

`provider_params` ya permite `:status`, así que un `PATCH` al `update` existente con solo `status` funcionaría. Se descarta: ese camino comparte `strong_params` con el form completo, y un bug futuro en el form podría hacer que el toggle toque `config`. Una acción `toggle_active` dedicada que solo escriba `status` hace imposible ese error por construcción.

```ruby
member { patch :toggle_active }
```

La acción alterna entre `"active"` e `"inactive"` leyendo el estado actual, en lugar de recibir el estado deseado como parámetro. Evita el caso de dos pestañas abiertas mandando el mismo destino.

Autorización: `before_action :authenticate_super_admin!` ya cubre todo el controlador, así que la acción nueva queda protegida sin trabajo adicional. El spec igual lo exige como escenario porque es la clase de garantía que no debe romperse en silencio.

### El estado `quoting` muestra resultados parciales, y se actualiza solo

Hoy la vista trata `quoting` y `quoted` como ramas excluyentes: si está cotizando, no muestra resultados aunque existan. Con varios proveedores respondiendo a distinta velocidad eso significa una pantalla vacía mientras hay datos disponibles. La rama de `quoting` pasa a renderizar las filas que ya llegaron junto al indicador de progreso.

**Se incluye el refresco automático vía Turbo Streams**, emitido desde `ProviderQuoteJob` al terminar cada proveedor. Inicialmente lo había dejado fuera de alcance razonando sobre tres fakes instantáneos, donde recargar es tolerable. Con seis APIs reales de latencia dispar deja de serlo: el productor quedaría recargando a ciegas sin saber si falta un proveedor o si ya terminó. El refresco no es un extra de esta pantalla, es lo que la hace usable — y separarlo en otro cambio dejaría este entregando una pantalla que en producción no sirve.

### La latencia percibida no es la suma de las APIs, pero la concurrencia sí importa

La petición HTTP **no** espera a los proveedores: `QuoteJob` encola un `ProviderQuoteJob` por proveedor y responde de inmediato. Sumar proveedores no hace más lenta la carga de la página. Lo que sí crece es el tiempo hasta tener la comparación completa, y ahí manda la concurrencia del worker.

`config/queue.yml` declara hoy `threads: 3`, `processes: 1`: **tres jobs en paralelo**. Con seis proveedores eso son dos tandas, así que el tiempo total es aproximadamente el doble de la API más lenta, no la suma de las seis. Con un `JOB_CONCURRENCY` o un `threads` mayor, las seis irían en una sola tanda.

El cuello de botella real no es el número de proveedores sino **el proveedor lento**. `ProviderQuoteJob` reintenta 3 veces con 5s de espera y el timeout de Faraday por defecto es 30s (`provider.config_for(:timeout) || 30`). Un proveedor colgado ocupa uno de los tres slots hasta ~100s (30+5+30+5+30) mientras los demás esperan turno. Con seis proveedores y uno caído, la comparación completa se degrada mucho más por ese uno que por los cinco sanos.

Hay una trampa acoplada si se decide subir la concurrencia. `config/database.yml:28` calcula `pool = RAILS_MAX_THREADS + 5`, y ese `+5` está dimensionado exactamente para el `threads: 3` actual (3 workers + 1 dispatcher + 1 supervisor). Como Solid Queue corre dentro de Puma (`SOLID_QUEUE_IN_PUMA: true`), comparte ese pool: subir `threads` sin subir el `+5` hace que Solid Queue se niegue a bootear **y se lleve Puma puesto**. El comentario en `database.yml:21-27` lo advierte. Para seis threads harían falta 8 conexiones, es decir `+8`.

Ajustar la concurrencia queda fuera de este cambio — hoy hay tres fakes instantáneos y no hay nada que optimizar. Lo que este cambio sí debe hacer es no empeorar el problema y dejarlo medido.

## Risks / Trade-offs

**Las coberturas vienen de `raw_response`, un JSON sin contrato** → La vista debe tolerar que falte la clave `coverage`, que venga vacía, o que un item no tenga `amount`. El spec cubre el caso de ausencia; la implementación usa acceso defensivo en lugar de asumir la forma. Los fakes siempre la devuelven, así que un test que solo use fakes no ejercitaría esto — hay que cubrirlo con un resultado sin coberturas construido a mano.

**Mostrar ocho coberturas por tarjeta alarga mucho la página** → Con tres proveedores son 24 filas de detalle. Si en la implementación resulta ilegible, la mitigación es colapsar las coberturas tras un disclosure de Flowbite por tarjeta, manteniendo el precio y el plan siempre visibles. Se decide con la pantalla armada, no antes.

**El toggle puede apagar todos los proveedores** → Con cero proveedores activos, `QuoteJob` no encola nada y la cotización queda en `quoting` para siempre, sin resultados ni error. No se agrega una validación que impida el último apagado — es una operación legítima —, pero el listado debe hacer evidente el estado, y vale considerar un aviso en la pantalla de cotización cuando no hay proveedores activos. Queda como pregunta abierta.

**El botón "Seleccionar" sigue sin funcionar** → Se rediseña una pantalla dejando su acción principal muerta. Es deliberado, pero el resultado es una pantalla que se ve terminada y no lo está. La implementación no debe darle prominencia visual de acción primaria si no hace nada. Con cuatro opciones por proveedor el problema se multiplica: pasan de 3 botones muertos a 24.

**Un proveedor lento retiene un slot del worker y demora toda la comparación** → Con `threads: 3` y reintentos de hasta ~100s, un proveedor colgado degrada la experiencia mucho más que cinco sanos. La mitigación real (bajar el timeout por proveedor, no reintentar timeouts, subir la concurrencia con su `pool` correspondiente) excede este cambio. Lo que sí corresponde acá es que la pantalla haga visible que se está esperando a un proveedor concreto, en lugar de mostrar un progreso anónimo: el spec ya exige mostrar los parciales y diferenciar los que fallan.

**Subir la concurrencia sin subir el pool tira Puma** → Si al ver la demora con seis proveedores alguien sube `threads` en `config/queue.yml`, tiene que subir en la misma proporción el `+5` de `config/database.yml:28`. Solid Queue corre dentro de Puma y comparte el pool; si no le alcanzan las conexiones se niega a arrancar y arrastra al servidor web. Está documentado en `database.yml:21-27`, pero es exactamente el tipo de nota que se pasa por alto bajo presión.

## Migration Plan

Sin migraciones de esquema ni cambios de datos. `providers.status` y `quote_results.status` ya soportan todo lo requerido.

El despliegue es de vistas y controladores; el rollback es revertir el commit. Omint permanece `inactive` durante y después del cambio — este trabajo no lo enciende, solo hace que encenderlo sea un clic seguro cuando se decida.

## Open Questions

- ¿Debe la pantalla de cotización avisar cuando no hay ningún proveedor activo? Hoy esa situación produce una cotización colgada en `quoting` sin explicación. Es un caso adyacente y podría resolverse aquí o en su propio cambio.
- ¿La vista pública (`public/quotes/show.html.erb`) debe recibir el mismo rediseño? Muestra los mismos resultados al cliente final, y dejar las dos divergiendo es deuda inmediata. Se decide al ver cuánto marcado es realmente compartible — si es mucho, sale un partial común.
- ¿Cuánto detalle de un proveedor fallido conviene mostrar al productor? El mensaje crudo del error puede ser técnico o filtrar detalles de la integración; mostrar solo "no pudo cotizar" es seguro pero opaco.
