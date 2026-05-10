# Roles y Permisos

## Roles

| Rol | Descripción |
|-----|-------------|
| `super_admin` | Equipo interno. Acceso global a todo. Gestiona proveedores, productores y finanzas. |
| `producer` | Productor de seguros independiente. Cotiza, gestiona clientes, ve sus pólizas y comisiones. |

## Estados de Productor

| Estado | Descripción |
|--------|-------------|
| `pending` | Se registró pero espera aprobación del super admin. No puede cotizar. |
| `active` | Aprobado. Tiene acceso completo al panel de productor. |
| `suspended` | Desactivado por el super admin. No puede iniciar sesión. |

## Matriz de Permisos

| Funcionalidad | Super Admin | Producer (active) | Producer (pending) |
|---------------|:-----------:|:-----------------:|:------------------:|
| **Dashboard global / Finanzas** | ✅ | ❌ | ❌ |
| Ver KPIs de toda la plataforma | ✅ | ❌ | ❌ |
| Ver comisiones por cobrar/pagar global | ✅ | ❌ | ❌ |
| **Gestión de Proveedores** | ✅ | ❌ | ❌ |
| Crear/editar/eliminar aseguradoras | ✅ | ❌ | ❌ |
| Crear/editar planes de seguro | ✅ | ❌ | ❌ |
| Configurar contratos de comisión | ✅ | ❌ | ❌ |
| **Gestión de Productores** | ✅ | ❌ | ❌ |
| Ver lista de productores | ✅ | ❌ | ❌ |
| Aprobar/rechazar productores pendientes | ✅ | ❌ | ❌ |
| Suspender/activar productores | ✅ | ❌ | ❌ |
| **Cotizador** | ❌ | ✅ | ❌ |
| Crear/editar/eliminar cotizaciones | ❌ | ✅ | ❌ |
| Ver comparador de precios | ❌ | ✅ | ❌ |
| Generar link público para cliente | ❌ | ✅ | ❌ |
| **Clientes (Travelers)** | ❌ | ✅ | ❌ |
| Crear/editar/ver viajeros | ❌ | ✅ | ❌ |
| **Pólizas** | ❌ | ✅ | ❌ |
| Ver sus pólizas emitidas | ❌ | ✅ | ❌ |
| Descargar documento de póliza | ❌ | ✅ | ❌ |
| **Finanzas del Productor** | ❌ | ✅ | ❌ |
| Ver estimado de comisiones acumuladas | ❌ | ✅ | ❌ |
| Ver comisiones por póliza | ❌ | ✅ | ❌ |
| Generar factura mensual de comisiones | ❌ | ✅ | ❌ |
| **Configuración** | ❌ | ✅ | ❌ |
| Editar su perfil | ✅ | ✅ | ❌ |
| Cambiar contraseña | ✅ | ✅ | ❌ |

## Implementación

Se usa `Action Policy` (más liviano que Pundit para Rails moderno). Cada controlador usa `authorize!` o `authorized_scope`.

### Ejemplo de Policy

```ruby
class QuotePolicy < ApplicationPolicy
  def index?
    user.producer? && user.active?
  end

  def create?
    user.producer? && user.active?
  end

  def update?
    user.producer? && user.active? && record.producer == user && record.editable?
  end

  def destroy?
    user.producer? && user.active? && record.producer == user && record.deletable?
  end

  class Scope < Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif user.producer? && user.active?
        scope.where(producer: user)
      else
        scope.none
      end
    end
  end
end
```

## Flujo de Aprobación de Productores

1. Productor se registra vía `/users/sign_up` (Devise).
2. Se crea con `role: producer`, `status: pending`.
3. Super admin recibe notificación (email opcional, dashboard sí).
4. Super admin va a `/admin/users` y presiona "Aprobar".
5. `status` cambia a `active`. El productor ya puede iniciar sesión y cotizar.
6. Si es rechazado, `status` cambia a `suspended`.

## Multi-tenancy y Roles

- `super_admin` opera **sin tenant**. `ApplicationController#set_current_tenant` debe manejar `current_user.super_admin?` para no setear tenant (o setear un tenant dummy si `acts_as_tenant` lo requiere).
- `producer` opera **con tenant** (`current_user.company`).
