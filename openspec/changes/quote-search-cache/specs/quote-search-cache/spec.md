## ADDED Requirements

### Requirement: Una búsqueda equivalente reciente no vuelve a consultar a los proveedores

Cuando una cotización nueva tiene los mismos parámetros de búsqueda que otra de la misma empresa resuelta dentro de la ventana de caché, el sistema SHALL reutilizar aquellos resultados y NO SHALL encolar trabajo contra los proveedores.

#### Scenario: Búsqueda repetida dentro de la ventana

- **WHEN** se crea una cotización con los mismos parámetros que otra resuelta hace dos minutos, con la ventana de caché en diez minutos
- **THEN** la cotización queda con los mismos resultados sin que se encole ningún trabajo de proveedor

#### Scenario: Búsqueda repetida fuera de la ventana

- **WHEN** la cotización equivalente más reciente se resolvió antes de la ventana de caché
- **THEN** se consulta a los proveedores normalmente

#### Scenario: No hay búsqueda previa equivalente

- **WHEN** ninguna cotización previa coincide en parámetros
- **THEN** se consulta a los proveedores normalmente

### Requirement: La equivalencia se calcula sobre los parámetros que mueven el precio

Dos búsquedas SHALL considerarse equivalentes solo si coinciden en origen, destino, fecha de salida, fecha de regreso, tipo de viaje, cantidad de viajeros y edades de los viajeros. Cualquier diferencia en esos valores SHALL producir una búsqueda distinta.

#### Scenario: Mismas edades en distinto orden

- **WHEN** una búsqueda declara edades `[40, 30]` y otra `[30, 40]`, con el resto igual
- **THEN** ambas se consideran la misma búsqueda

#### Scenario: Misma cantidad de viajeros con edades distintas

- **WHEN** dos búsquedas tienen dos viajeros, una con edades `[30, 30]` y otra con `[30, 70]`
- **THEN** se consideran búsquedas distintas y la segunda consulta a los proveedores

#### Scenario: Distinta fecha de regreso

- **WHEN** dos búsquedas coinciden en todo salvo la fecha de regreso
- **THEN** se consideran distintas, porque la duración del viaje cambia el precio

#### Scenario: Origen y destino escritos de forma diferente

- **WHEN** una búsqueda declara origen `"Buenos Aires"` y otra `" buenos aires "`
- **THEN** ambas se consideran la misma búsqueda

#### Scenario: Distinto tipo de viaje

- **WHEN** dos búsquedas coinciden en todo salvo `trip_type`
- **THEN** se consideran distintas

### Requirement: El caché nunca cruza empresas

La reutilización SHALL estar acotada a la empresa de la cotización. Una búsqueda de una empresa NO SHALL reutilizar resultados de otra, aunque los parámetros coincidan exactamente.

#### Scenario: Dos empresas con la misma búsqueda

- **WHEN** dos empresas distintas crean cotizaciones con parámetros idénticos dentro de la ventana
- **THEN** cada una consulta a los proveedores por su cuenta y no comparte resultados

### Requirement: Los fallos de proveedor no se reutilizan

El sistema NO SHALL reutilizar resultados en estado `error`. Una búsqueda previa donde un proveedor falló SHALL poder reutilizar los resultados exitosos de los demás, pero el proveedor que falló NO SHALL quedar marcado como fallido por herencia.

#### Scenario: Búsqueda previa con un proveedor caído

- **WHEN** se reutiliza una búsqueda donde tres proveedores respondieron y uno falló
- **THEN** se reutilizan los resultados de los tres exitosos y no se copia el resultado en error

#### Scenario: Búsqueda previa donde todos fallaron

- **WHEN** la única búsqueda equivalente reciente terminó sin ningún resultado exitoso
- **THEN** no se reutiliza y se consulta a los proveedores normalmente

### Requirement: Una cotización resuelta desde caché es indistinguible para quien la mira

Una cotización resuelta reutilizando una búsqueda previa SHALL quedar en el mismo estado final y con resultados equivalentes a una resuelta consultando proveedores, de modo que las pantallas de comparación no necesiten distinguir el origen.

#### Scenario: Estado final de una cotización cacheada

- **WHEN** una cotización se resuelve desde caché
- **THEN** queda en estado `quoted` con sus resultados agrupados por proveedor igual que cualquier otra

#### Scenario: Trazabilidad del origen

- **WHEN** se inspecciona una cotización resuelta desde caché
- **THEN** queda registrado que se resolvió por reutilización, sin que eso altere lo que ven las pantallas
