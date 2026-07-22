## Context

El fan-out ya es asíncrono y progresivo: `QuoteJob` encola un `ProviderQuoteJob` por proveedor activo, cada uno emite su resultado por Turbo Stream y la pantalla se va llenando. La petición HTTP no espera a nadie. Lo que cuesta es el tiempo hasta tener la comparación completa: 7,3 segundos medidos con cuatro fakes a 3s, 4s y 6s, y `threads: 3`.

Ese costo se paga entero cada vez, aunque la búsqueda sea idéntica a una de hace dos minutos. Los parámetros que mueven el precio ya están todos en `Quote`: `origin`, `destination`, `departure_date`, `return_date`, `trip_type`, `travelers_count` y las edades en `metadata["ages"]` — esta última es la que se pasa por alto con más facilidad, y los fakes ya aplican un recargo de 1,65 cuando `max_age >= 65`.

Dos restricciones que salieron de mirar el código y no de suponer:

- **`valid_until` hoy no existe como columna.** Los fakes y `ExampleProvider` lo devuelven dentro de `raw_response`, que es JSON en un `longtext`; `OmintProvider` —el único proveedor real— **no lo devuelve en absoluto**. Así que no se puede filtrar por vigencia en SQL ni depender de que el proveedor la informe.
- **Hay dos puntos que emiten pólizas**, y solo uno debe validar vigencia: `Public::LandingController#complete_purchase!` (el cliente comprando) y `WebhookProcessorJob` (el proveedor confirmando una compra ya hecha).

## Goals / Non-Goals

**Goals:**

- Que una búsqueda repetida dentro de una ventana corta se resuelva sin volver a llamar a los proveedores.
- Que no se muestre ni se venda a un precio vencido.
- Que el ahorro sea medible en lugar de supuesto.

**Non-Goals:**

- **Revalidar el precio contra el proveedor antes de comprar.** Es la protección correcta a largo plazo y la única que cubre el caso de un `external_quote_id` que el proveedor ya no acepta, pero requiere un método nuevo en `BaseProvider` e implementarlo por proveedor. Este change se limita a no vender lo vencido; ver Riesgos.
- **Cachear a nivel de proveedor individual.** Reutilizar la respuesta de Assist Card mientras se consulta al resto daría comparaciones mezcladas en el tiempo. Se reutiliza la búsqueda completa o ninguna.
- **Compartir caché entre empresas.** Cada `Company` tiene su moneda y podría tener márgenes propios.
- **Cachear cotizaciones fallidas.**

## Decisions

### El fingerprint se guarda en una columna, no se calcula al consultar

`quotes` suma `search_fingerprint`: un hash de los parámetros normalizados, con índice compuesto `(company_id, search_fingerprint, created_at)`. Buscar por siete campos sueltos exigiría un índice ancho y comparaciones sobre `metadata`, que es JSON en `longtext` y no es indexable de forma útil en MariaDB.

Se calcula en un callback antes de guardar, de modo que exista para cualquier `Quote` sin que cada llamador se acuerde de setearlo.

Normalización antes de hashear, porque cada una corresponde a un escenario del spec:

- `origin` y `destination`: sin espacios sobrantes y en minúsculas.
- `ages`: convertidas a entero y **ordenadas** — `[40, 30]` y `[30, 40]` son la misma búsqueda.
- fechas: en formato ISO, para no depender de cómo se serialicen.
- `travelers_count` y `trip_type`: tal cual.

Alternativa considerada: comparar campo a campo con un `where` sobre la última cotización equivalente. Es más legible y evita la columna, pero arrastra el problema de `metadata["ages"]` y obliga a repetir las reglas de normalización en cada consulta. El fingerprint las concentra en un solo lugar.

### La reutilización copia los resultados, no los referencia

Al reutilizar, se crean `QuoteResult` nuevos asociados a la cotización nueva, copiando los de la búsqueda previa. No se apunta a los originales.

Copiar mantiene la invariante que ya tiene el sistema —una cotización es dueña de sus resultados— y hace que todo lo construido en el change anterior funcione sin cambios: `offers_by_provider`, la comparación, los Turbo Streams. Referenciar obligaría a `quote_results` a pertenecer a varias cotizaciones y a repensar `dependent: :destroy`.

El costo es duplicación de filas. Con cuatro proveedores × cuatro planes son trece filas por cotización cacheada; a cambio, el historial de cada cotización queda íntegro y auditable, que en seguros importa más que el espacio.

### La vigencia vive en una columna nueva, con default cuando el proveedor calla

`quote_results` suma `valid_until` (datetime, nullable). `ProviderQuoteJob` lo toma de la respuesta del proveedor si viene, y si no aplica un valor por defecto configurable.

Es la única forma de filtrar por vigencia en SQL: hoy el dato está dentro de `raw_response` y Omint ni siquiera lo envía. Poner un default es una decisión con filo —inventa una vigencia que el proveedor no prometió— pero la alternativa es tratar los resultados de Omint como eternos, que es peor.

La vigencia se evalúa además **al reutilizar**, no solo al crear: una entrada puede estar dentro de la ventana de caché y aun así tener resultados vencidos si el proveedor dio una vigencia más corta que la ventana.

### La ventana de caché es corta y configurable

La ventana por defecto se mide en minutos, no en horas. El caso que motiva este change es el productor que corrige un dato y vuelve a cotizar, o dos clientes consultando lo mismo casi a la vez — no el que vuelve al día siguiente. Una ventana corta también acota el daño de cualquier error de normalización en el fingerprint.

Configurable para poder subirla si la medición muestra que conviene, y bajarla a cero para desactivar el caché sin revertir código.

### La validación de vigencia va en el checkout, no en el modelo

`Public::LandingController#complete_purchase!` verifica vigencia antes de llamar a `PolicyIssuer`. No se pone en `PolicyIssuer` porque ese mismo objeto lo usa `WebhookProcessorJob`, donde la validación sería dañina: el webhook llega desde el proveedor confirmando una compra ya concretada, y rechazarla dejaría al cliente pagado y sin póliza.

Es una asimetría deliberada, y el spec la fija explícitamente para que nadie la "corrija" después moviendo la validación a un lugar común.

## Risks / Trade-offs

**Un `external_quote_id` reutilizado puede ser rechazado por el proveedor** → Es el riesgo más serio y este change no lo elimina. Al copiar resultados se copian identificadores que el proveedor emitió para otra cotización; un proveedor real puede rechazarlos al comprar aunque el precio siga vigente. La mitigación completa es revalidar contra el proveedor antes de emitir, que queda fuera de alcance. Mientras tanto: ventana corta, y **conviene probar el caché primero con los fakes y con Omint apagado**, antes de habilitarlo con un proveedor real.

**El default de vigencia inventa una promesa que el proveedor no hizo** → Omint no informa `valid_until`, así que cualquier valor es una suposición. Un default agresivo (pocos minutos) hace el caché casi inútil para ese proveedor; uno laxo arriesga vender vencido. Se resuelve con un default conservador y configurable, y revisándolo cuando Omint esté validado y se sepa cuánto honra sus precios.

**Un error en la normalización del fingerprint mezcla búsquedas distintas** → Sería el peor fallo posible: mostrarle a alguien el precio de otra búsqueda. Los escenarios del spec cubren las normalizaciones una por una (orden de edades, mayúsculas, fecha de regreso, `trip_type`), y conviene que los tests de fingerprint sean de igualdad **y de desigualdad**: es tan importante que dos búsquedas distintas no colisionen como que dos iguales coincidan.

**El caché puede ocultar que un proveedor se cayó** → Si un proveedor deja de responder, las búsquedas cacheadas siguen mostrando sus precios hasta que la ventana expira. Con ventana de minutos el efecto es acotado, pero conviene tenerlo presente al diagnosticar.

**Menos llamadas reales significa menos señal sobre la latencia** → El registro del origen de cada cotización existe también para esto: si el ratio de caché sube mucho, las mediciones de tiempo de fan-out dejan de ser representativas.

## Migration Plan

Dos columnas nuevas, ambas nullable, sin backfill: las cotizaciones existentes quedan sin fingerprint y por lo tanto nunca se reutilizan, que es el comportamiento seguro. Los resultados previos quedan sin `valid_until`; se los debe tratar como vencidos a efectos de reutilización, y como válidos a efectos de compra para no romper cotizaciones en curso al momento del deploy.

Con la ventana en cero el sistema se comporta exactamente como hoy, así que el rollback funcional no exige revertir el deploy.

## Open Questions

- ¿Cuánto debería durar la ventana por defecto? Sin datos de producción cualquier número es arbitrario; conviene arrancar conservador y ajustarlo con la medición del ratio de reutilización.
- ¿Qué vigencia por defecto asumir para un proveedor que no la informa? Depende de cuánto honre Omint sus precios, que se sabrá recién al validarlo contra su ambiente de test.
- ¿La reutilización debería avisarse en la pantalla? Mostrar "resultados de hace 3 minutos" es más honesto con el productor, pero agrega ruido a una comparación que se acaba de rediseñar. El spec deja hoy la cotización indistinguible a propósito.
