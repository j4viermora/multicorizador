## ADDED Requirements

### Requirement: Los resultados se agrupan en una fila por proveedor

La pantalla de comparación SHALL agrupar los resultados por proveedor, presentando cada proveedor como una fila que contiene todas sus opciones de plan. Un proveedor con múltiples `QuoteResult` para la misma cotización NO SHALL aparecer en más de una fila.

#### Scenario: Tres proveedores con cuatro opciones cada uno

- **WHEN** una cotización tiene doce resultados exitosos, cuatro por cada uno de tres proveedores
- **THEN** se muestran tres filas, cada una identificada por su proveedor y conteniendo sus cuatro opciones

#### Scenario: Un proveedor devuelve una sola opción

- **WHEN** un proveedor produce un único resultado exitoso
- **THEN** su fila se muestra con esa única opción, sin espacios vacíos donde irían las demás

### Requirement: Las opciones dentro de una fila se ordenan por precio ascendente

Dentro de la fila de un proveedor, las opciones SHALL ordenarse por `price_cents` de menor a mayor, de modo que la escala de planes se lea de más económico a más caro en la misma dirección en todas las filas.

#### Scenario: Opciones de un proveedor en desorden

- **WHEN** un proveedor devuelve sus cuatro planes en orden de creación arbitrario
- **THEN** su fila los presenta ordenados de menor a mayor precio

#### Scenario: Dos opciones empatan en precio

- **WHEN** dos opciones del mismo proveedor tienen el mismo `price_cents`
- **THEN** ambas se muestran, sin que ninguna se omita ni se duplique

### Requirement: Las filas de proveedor se ordenan por su opción más económica

Las filas SHALL ordenarse por el `price_cents` mínimo entre las opciones de cada proveedor, de manera que el proveedor con la entrada más barata aparezca primero.

#### Scenario: Tres proveedores con distintos mínimos

- **WHEN** el plan más barato de Assist Card cuesta USD 168, el de Universal USD 195 y el de Travel Ace USD 210
- **THEN** las filas se muestran en el orden Assist Card, Universal Assistance, Travel Ace

### Requirement: Cada opción expone su detalle de coberturas

Cada opción SHALL mostrar las coberturas que el proveedor devolvió en `raw_response["coverage"]`, con nombre y monto de cada una. Cuando una opción no trae coberturas, SHALL seguir siendo válida mostrando precio y plan sin una sección de coberturas vacía.

#### Scenario: Opción con coberturas

- **WHEN** una opción tiene ocho entradas en `raw_response["coverage"]`
- **THEN** se muestran el nombre y el monto de cada una de las ocho

#### Scenario: Opción sin coberturas

- **WHEN** una opción exitosa no tiene la clave `coverage` en `raw_response`
- **THEN** se muestran precio y nombre de plan sin renderizar una sección de coberturas

### Requirement: La comparación es legible en pantallas angostas

La fila de opciones SHALL seguir siendo utilizable cuando el ancho disponible no alcanza para mostrar todas las opciones lado a lado, sin provocar scroll horizontal del documento completo.

#### Scenario: Cuatro opciones en viewport móvil

- **WHEN** se abre la comparación en un viewport angosto con cuatro opciones por fila
- **THEN** las opciones siguen siendo accesibles y el `body` de la página no scrollea horizontalmente

#### Scenario: Un proveedor devuelve más opciones de las previstas

- **WHEN** un proveedor devuelve siete opciones para una misma cotización
- **THEN** todas se presentan en su fila sin romper el layout ni desbordar las filas vecinas

### Requirement: La cotización en curso informa su progreso

Cuando una cotización está en estado `quoting`, la pantalla SHALL indicar que se está consultando a los proveedores y SHALL mostrar las filas de los proveedores que ya respondieron, en lugar de ocultarlas hasta que todos respondan.

#### Scenario: Cotización con respuestas parciales

- **WHEN** la cotización está en `quoting` y dos de tres proveedores ya crearon sus resultados exitosos
- **THEN** se muestran esas dos filas junto al indicador de consulta en curso

#### Scenario: Cotización recién enviada

- **WHEN** la cotización está en `quoting` y ningún proveedor respondió todavía
- **THEN** se muestra el indicador de consulta en curso sin filas de resultado

### Requirement: Los proveedores que fallan son visibles

La pantalla SHALL mostrar los proveedores cuyos resultados tienen `status: "error"` de forma diferenciada, identificando al proveedor que falló. Un proveedor caído NO SHALL desaparecer silenciosamente de la comparación.

#### Scenario: Un proveedor falla y otros responden

- **WHEN** dos proveedores producen resultados exitosos y un tercero solo produce un resultado en `error`
- **THEN** se muestran las dos filas exitosas y una indicación diferenciada de que el tercer proveedor no pudo cotizar

#### Scenario: Todos los proveedores fallan

- **WHEN** todos los resultados de una cotización tienen `status: "error"`
- **THEN** la pantalla informa que ningún proveedor pudo cotizar, en lugar del mensaje genérico de ausencia de resultados

### Requirement: La comparación reutiliza el vocabulario de componentes del proyecto

Las vistas de resultados SHALL construirse con las clases de componente definidas en el `@layer components` de `app/assets/tailwind/application.css`, utilidades Tailwind y Flowbite, extendiendo esa capa cuando haga falta una pieza nueva en lugar de inlinear cadenas largas de utilidades. Los iconos SHALL ser Tabler Icons.

#### Scenario: Auditoría de la vista de resultados

- **WHEN** se inspecciona el marcado de la pantalla de comparación
- **THEN** los componentes reutilizables provienen del `@layer components`, todos los iconos son Tabler Icons y no se introducen clases de otro framework CSS

#### Scenario: La comparación necesita una pieza visual nueva

- **WHEN** el rediseño requiere un componente que no existe en el `@layer components`
- **THEN** se agrega a esa capa con `@apply` en lugar de repetir la cadena de utilidades en la vista
