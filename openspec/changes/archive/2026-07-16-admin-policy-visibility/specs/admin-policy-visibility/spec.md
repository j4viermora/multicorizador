## ADDED Requirements

### Requirement: Listado de pólizas en el admin
El sistema SHALL proveer una vista en el namespace de administración donde un usuario `super_admin` puede listar todas las pólizas emitidas en el sistema, sin importar la company/tenant de origen.

#### Scenario: Admin ve pólizas de todas las companies
- **WHEN** un `super_admin` autenticado accede al listado de pólizas del admin
- **THEN** el sistema muestra todas las `Policy` existentes, incluidas las de distintas companies/tenants

#### Scenario: Usuario no admin no puede acceder
- **WHEN** un usuario `producer` (no `super_admin`) intenta acceder al listado de pólizas del admin
- **THEN** el sistema deniega el acceso, igual que para el resto de las pantallas de `/admin`

### Requirement: Filtro por canal de venta
El listado de pólizas del admin SHALL permitir filtrar por canal de venta (directo por Ruka, o vía producer afiliado).

#### Scenario: Filtrar solo pólizas directas
- **WHEN** el admin aplica el filtro de canal "directo"
- **THEN** el listado muestra únicamente las pólizas cuyo canal corresponde a venta directa de Ruka

#### Scenario: Filtrar solo pólizas de producers
- **WHEN** el admin aplica el filtro de canal "producer"
- **THEN** el listado muestra únicamente las pólizas cuyo canal corresponde a venta vía producer afiliado

### Requirement: Totales por canal en el dashboard
El dashboard principal de admin SHALL mostrar el total de pólizas emitidas directamente por Ruka y el total de pólizas emitidas vía producers afiliados, como valores reales calculados desde los datos existentes (no un valor fijo).

#### Scenario: Dashboard refleja pólizas reales
- **WHEN** existen pólizas emitidas con distintos canales en el sistema
- **THEN** el dashboard de admin muestra el conteo correcto de pólizas por cada canal, actualizado según los datos existentes

#### Scenario: Sin pólizas de producers todavía
- **WHEN** no existe ninguna póliza emitida vía producer afiliado
- **THEN** el dashboard muestra el total correspondiente en cero, sin que esto se interprete como un error o dato faltante
