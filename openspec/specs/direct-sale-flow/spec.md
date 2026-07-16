## Purpose

Define el comportamiento del flujo de venta directa de seguros de viaje en la landing pública de Ruka (`ruka.com`), unificado con el motor de cotización y emisión de pólizas usado por el flujo de `/producer`.

## Requirements

### Requirement: Motor de cotización único
El sistema SHALL usar un único mecanismo de orquestación de cotizaciones (cotizar contra `Provider.active` y persistir `QuoteResult`) tanto para cotizaciones creadas desde `/producer` como para cotizaciones creadas desde la landing pública de venta directa. No SHALL existir un segundo camino que cotice de forma síncrona sin persistir intentos fallidos por proveedor.

#### Scenario: Cotización desde la landing pública usa el mismo motor que el producer
- **WHEN** un visitante sin producer asociado envía una búsqueda de cotización desde `ruka.com`
- **THEN** el sistema crea un `Quote` persistido y encola la cotización contra cada `Provider` activo por el mismo mecanismo que usa el flujo de `/producer`

#### Scenario: Un proveedor que falla no bloquea a los demás
- **WHEN** uno de los proveedores activos falla al cotizar (error o timeout)
- **THEN** el sistema registra un `QuoteResult` con estado de error para ese proveedor y continúa procesando los demás proveedores sin interrumpir la cotización

### Requirement: Estado de la cotización refleja resultados reales
El `Quote` SHALL pasar a estado `quoted` únicamente cuando exista al menos un `QuoteResult` en estado exitoso asociado a ese `Quote`. Si todos los proveedores fallan, el `Quote` NO SHALL quedar en estado `quoted`.

#### Scenario: Todos los proveedores fallan
- **WHEN** se completan todos los intentos de cotización de un `Quote` y ninguno tuvo éxito
- **THEN** el `Quote` no queda en estado `quoted` y el sistema expone al usuario que la búsqueda no obtuvo resultados

#### Scenario: Al menos un proveedor responde con éxito
- **WHEN** se completan todos los intentos de cotización de un `Quote` y al menos uno tuvo éxito
- **THEN** el `Quote` pasa a estado `quoted` y los resultados exitosos quedan disponibles para comparación

### Requirement: Toda compra emite una póliza real
El sistema SHALL crear un registro `Policy` real como resultado de cualquier compra completada, incluida la compra realizada directamente en la landing pública de Ruka. No SHALL existir un camino de compra que solo persista datos de la compra en `Quote.metadata` sin crear un `Policy` asociado.

#### Scenario: Compra directa en ruka.com emite póliza
- **WHEN** un usuario completa el checkout de compra en la landing pública, seleccionando uno de los resultados de cotización exitosos
- **THEN** el sistema crea un registro `Policy` asociado al `QuoteResult` elegido, y el `Quote` pasa a estado `purchased`

#### Scenario: Compra vía flujo de producer sigue emitiendo póliza
- **WHEN** se procesa un webhook válido de un proveedor confirmando la emisión de una póliza para un `QuoteResult` de un `Quote` gestionado por un producer
- **THEN** el sistema crea (o reutiliza, si ya existe por `policy_number`) el registro `Policy` correspondiente, igual que antes de este change

### Requirement: Trazabilidad de canal de venta en la póliza
Todo `Policy` SHALL registrar el canal por el cual se originó la venta (por ejemplo, venta directa de Ruka). El sistema SHALL permitir distinguir, a partir del `Policy`, si la venta fue directa, sin necesidad de inferirlo desde otros registros.

#### Scenario: Póliza de venta directa queda marcada como tal
- **WHEN** se emite un `Policy` como resultado de una compra realizada en la landing pública de venta directa
- **THEN** el `Policy` queda registrado con el canal correspondiente a venta directa de Ruka
