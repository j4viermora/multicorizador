## ADDED Requirements

### Requirement: Cada resultado registra hasta cuándo es válido

Todo `QuoteResult` exitoso SHALL persistir su fecha de vencimiento en una columna consultable. Cuando el proveedor informa una vigencia, esa SHALL ser la fecha registrada; cuando no la informa, SHALL aplicarse una vigencia por defecto configurable.

#### Scenario: El proveedor informa vigencia

- **WHEN** un proveedor devuelve una cotización con vigencia de 24 horas
- **THEN** el resultado registra esa fecha de vencimiento

#### Scenario: El proveedor no informa vigencia

- **WHEN** un proveedor devuelve una cotización sin dato de vigencia
- **THEN** el resultado registra el vencimiento por defecto en lugar de quedar sin fecha

#### Scenario: La vigencia del proveedor manda sobre la ventana de caché

- **WHEN** un proveedor informa una vigencia más corta que la ventana de caché
- **THEN** el resultado deja de reutilizarse al vencer, aunque la ventana de caché siga abierta

### Requirement: Los resultados vencidos no se reutilizan

El sistema NO SHALL reutilizar resultados cuya fecha de vencimiento ya pasó, aunque la búsqueda sea equivalente y esté dentro de la ventana de caché.

#### Scenario: Búsqueda equivalente con resultados vencidos

- **WHEN** existe una búsqueda equivalente reciente cuyos resultados ya vencieron
- **THEN** se consulta a los proveedores en lugar de reutilizarlos

#### Scenario: Búsqueda equivalente con vigencia parcial

- **WHEN** una búsqueda previa tiene resultados de dos proveedores y solo los de uno siguen vigentes
- **THEN** no se reutiliza parcialmente: se consulta a los proveedores para obtener una comparación completa y coherente

### Requirement: No se emiten pólizas sobre cotizaciones vencidas

El checkout SHALL verificar la vigencia del resultado elegido antes de emitir la póliza, y SHALL rechazar la operación si venció. Emitir sobre un precio que el proveedor ya no honra traslada la diferencia a la agencia.

#### Scenario: Compra sobre un resultado vigente

- **WHEN** un cliente compra un plan cuyo resultado sigue vigente
- **THEN** la póliza se emite normalmente

#### Scenario: Compra sobre un resultado vencido

- **WHEN** un cliente compra un plan cuyo resultado ya venció
- **THEN** no se emite ninguna póliza y se le informa que la cotización expiró, ofreciéndole volver a cotizar

#### Scenario: La cotización vence mientras el cliente completa sus datos

- **WHEN** el resultado estaba vigente al abrir el checkout pero vence antes de confirmar
- **THEN** la validación se aplica en el momento de emitir, no en el de mostrar, y la operación se rechaza

### Requirement: Los webhooks de proveedor no se rechazan por vigencia

`WebhookProcessorJob` NO SHALL aplicar la validación de vigencia. Un webhook llega desde el proveedor confirmando una compra ya concretada de su lado; rechazarla dejaría al cliente pagado y sin póliza registrada.

#### Scenario: Webhook sobre un resultado vencido

- **WHEN** llega un webhook de compra para un resultado cuya vigencia ya pasó
- **THEN** la póliza se emite igual, porque el proveedor ya confirmó la operación
