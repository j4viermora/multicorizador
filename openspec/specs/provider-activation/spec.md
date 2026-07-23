## Purpose

Define el control sobre qué proveedores participan de una cotización: quién puede activarlos o desactivarlos y qué efecto tiene sobre el fan-out de `QuoteJob`.

## Requirements

### Requirement: El super admin activa y desactiva proveedores desde el listado

El listado de proveedores SHALL ofrecer una acción que alterne el `status` de un proveedor entre `active` e `inactive` sin abrir el formulario de edición y sin exigir el reenvío de `config`.

#### Scenario: Activar un proveedor inactivo

- **WHEN** un super admin acciona el toggle sobre un proveedor con `status: "inactive"`
- **THEN** el proveedor queda con `status: "active"` y el listado refleja el nuevo estado

#### Scenario: Desactivar un proveedor activo

- **WHEN** un super admin acciona el toggle sobre un proveedor con `status: "active"`
- **THEN** el proveedor queda con `status: "inactive"` y el listado refleja el nuevo estado

#### Scenario: El toggle preserva la configuración

- **WHEN** un super admin alterna el estado de un proveedor cuyo `config` contiene credenciales
- **THEN** el `config` queda idéntico antes y después de la operación

### Requirement: Solo un super admin puede alterar la activación

La acción de toggle SHALL estar restringida a usuarios con rol `super_admin`, igual que el resto del namespace `/admin`.

#### Scenario: Un productor intenta usar el toggle

- **WHEN** un usuario con rol `producer` invoca la acción de toggle
- **THEN** la petición es rechazada y el `status` del proveedor no cambia

#### Scenario: Un visitante sin sesión intenta usar el toggle

- **WHEN** una petición sin sesión autenticada invoca la acción de toggle
- **THEN** la petición es rechazada y el `status` del proveedor no cambia

### Requirement: La activación determina la participación en el fan-out

Un proveedor con `status: "active"` SHALL recibir un `ProviderQuoteJob` cuando se cotiza; uno con `status: "inactive"` NO SHALL recibirlo. Este es el contrato existente de `QuoteJob`, que este cambio preserva.

#### Scenario: Cotizar con un proveedor desactivado

- **WHEN** se ejecuta `QuoteJob` con tres proveedores activos y uno inactivo
- **THEN** se encolan exactamente tres `ProviderQuoteJob`, ninguno para el inactivo

#### Scenario: Activar un proveedor y volver a cotizar

- **WHEN** un super admin activa un proveedor previamente inactivo y luego se ejecuta `QuoteJob`
- **THEN** ese proveedor recibe su `ProviderQuoteJob` y puede producir un `QuoteResult`

### Requirement: El listado comunica el efecto de la activación

El listado SHALL presentar el estado de cada proveedor de forma legible y distinguir los que participarán de la próxima cotización de los que no, usando las clases de componente del proyecto y Tabler Icons.

#### Scenario: Listado con proveedores mixtos

- **WHEN** un super admin abre el listado con cuatro proveedores activos y uno inactivo
- **THEN** cada fila indica su estado de forma visualmente distinguible

#### Scenario: El toggle convive con la acción de editar

- **WHEN** se inspecciona una fila del listado
- **THEN** la acción de toggle y el enlace de edición son distinguibles entre sí, y el formulario de edición sigue usando `simple_form_for` con `f.input`
