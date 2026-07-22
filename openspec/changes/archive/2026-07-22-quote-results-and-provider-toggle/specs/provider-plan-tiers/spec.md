## ADDED Requirements

### Requirement: Un proveedor puede devolver múltiples opciones para una búsqueda

`BaseProvider#quote` SHALL admitir como retorno un hash único o un array de hashes, cada uno representando una opción de plan cotizable. `ProviderQuoteJob` SHALL crear un `QuoteResult` por cada opción devuelta, todos asociados al mismo `provider` y `quote`.

#### Scenario: Proveedor devuelve un array de opciones

- **WHEN** un proveedor devuelve cuatro hashes de cotización para una búsqueda
- **THEN** se crean cuatro `QuoteResult` con `status: "success"`, todos con el mismo `provider_id` y `quote_id`

#### Scenario: Proveedor devuelve un hash único

- **WHEN** un proveedor devuelve un único hash de cotización
- **THEN** se crea exactamente un `QuoteResult`, sin que el proveedor deba envolverlo en un array

#### Scenario: Un proveedor falla mientras otros devuelven varias opciones

- **WHEN** un proveedor lanza una excepción durante la cotización
- **THEN** se crea un único `QuoteResult` con `status: "error"` para ese proveedor, sin afectar las opciones ya creadas por los demás

### Requirement: Cada opción es identificable de forma independiente

Cada opción devuelta por un proveedor SHALL traer su propio `external_quote_id` y su propio `plan_name`, de modo que dos opciones del mismo proveedor sean distinguibles entre sí y referenciables por separado.

#### Scenario: Cuatro opciones del mismo proveedor

- **WHEN** un proveedor devuelve sus cuatro niveles de plan
- **THEN** cada `QuoteResult` resultante tiene un `external_quote_id` distinto y un `plan_name` distinto

### Requirement: Los proveedores fake ofrecen una escala de cuatro planes

Cada proveedor fake SHALL devolver cuatro opciones para toda búsqueda válida, formando una escala de menor a mayor precio en la que las coberturas crecen junto con el precio. La escala SHALL responder a los parámetros de la búsqueda igual que el plan único actual: días de viaje, cantidad de viajeros y recargo por edad.

#### Scenario: Cotización estándar contra un fake

- **WHEN** se cotiza un viaje de 10 días para un viajero contra `AssistCardFake`
- **THEN** el proveedor devuelve cuatro opciones de precios distintos, ordenables de menor a mayor

#### Scenario: Las coberturas acompañan al precio

- **WHEN** se comparan la opción más económica y la más cara de un mismo fake
- **THEN** la más cara ofrece montos de cobertura mayores o coberturas adicionales respecto de la más económica

#### Scenario: La escala responde a la duración del viaje

- **WHEN** se cotiza el mismo destino para 5 días y para 20 días contra el mismo fake
- **THEN** cada opción de la escala de 20 días cuesta más que su equivalente en la de 5 días

#### Scenario: La escala responde al recargo por edad

- **WHEN** se cotiza un grupo que incluye un viajero de 65 años o más
- **THEN** las cuatro opciones aplican el recargo por edad, no solo algunas de ellas
