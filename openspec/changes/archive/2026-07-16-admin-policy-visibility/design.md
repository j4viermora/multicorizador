## Context

Hoy `Admin::DashboardController#index` expone tres tarjetas (`stat`): productores pendientes, total de proveedores, y un total de pólizas hardcodeado en 0. No hay ningún controller/vista para listar pólizas en `/admin`. El único lugar donde se listan pólizas hoy es `Producer::PoliciesController` (`resources :policies, only: [:index, :show]` bajo `/producer`), scopeado implícitamente al tenant/producer actual vía `acts_as_tenant`.

El admin corre con `ActsAsTenant.current_tenant = nil` (`ApplicationController#set_current_tenant`, rama `super_admin?`). Con tenant `nil`, `acts_as_tenant` no aplica scoping automático — `Policy.all` ya devuelve todas las filas de todas las companies. Esto es importante: **no hace falta ningún cambio de tenancy para que el admin vea todo**, el gap es puramente de falta de controller/vista/routes.

Este change depende del campo de canal en `Policy` (`sold_via`/`channel`, valores `"direct"` / `"producer"`) introducido por `unify-direct-sale-flow`. Sin ese campo no hay forma de agrupar "nuestro" vs "de afiliados".

## Goals / Non-Goals

**Goals:**
- Admin puede listar todas las `Policy` del sistema, con filtro por canal (`direct` / `producer`).
- Dashboard de admin muestra dos totales reales: pólizas emitidas directo por Ruka, y pólizas emitidas vía producers.
- Funciona correctamente aunque hoy el canal `producer` esté vacío (0 registros) — no requiere datos de la Fase 2 para ser útil ni para construirse.

**Non-Goals:**
- Cálculo o visualización de comisiones (fase futura, depende del modelo de `CommissionRate` que todavía no existe).
- Filtrado/atribución por producer individual (ej. "cuánto vendió javiermora") — eso requiere el link de producer real (Fase 2) y no tiene sentido hasta que existan ventas por ese canal.
- Cambios a `acts_as_tenant` o al modelo de multi-tenancy — fuera de alcance, no hace falta tocarlo para este change.

## Decisions

### 1. Nuevo `Admin::PoliciesController`, sin tocar el existente de producer
Se agrega `app/controllers/admin/policies_controller.rb` (namespace `admin`, `before_action :authenticate_super_admin!`, igual que el resto de `admin/*`), separado de `Producer::PoliciesController`. No se reutiliza/hereda entre ambos porque tienen alcance distinto (uno ve todo el sistema, el otro solo lo propio) y forzar herencia acoplaría dos controllers con reglas de autorización distintas.

**Alternativa considerada**: un solo `PoliciesController` compartido con lógica condicional según rol. Se descarta por seguir la convención ya establecida en el proyecto (namespaces `admin/*` y `producer/*` completamente separados, ver `config/routes.rb`), y por mantener las queries explícitas en vez de condicionales por rol dentro del mismo controller.

### 2. Filtro por canal con Ransack
El proyecto ya usa `ransack` para búsqueda/filtro (`CLAUDE.md`). El filtro de canal en `admin/policies#index` se implementa con `ransack` (`q[sold_via_eq]=direct`), consistente con el resto del admin, sin agregar una dependencia nueva.

### 3. Totales del dashboard: conteo directo por `group(:sold_via).count`
Se reemplaza `@total_policies = 0` por dos valores (`Policy.group(:sold_via).count`, o dos scopes `Policy.direct.count` / `Policy.producer_sold.count` si se agregan scopes al modelo). Se prioriza un cálculo simple en el controller del dashboard — no se introduce un service/objeto de reporting nuevo para dos números; si en el futuro el dashboard crece (más métricas, series temporales), se puede extraer entonces.

## Risks / Trade-offs

- [El campo de canal puede llamarse distinto a `sold_via` según cómo se implemente `unify-direct-sale-flow`] → Mitigación: este change no arranca su implementación hasta confirmar el nombre final de la columna en el change del que depende.
- [Sin datos reales de canal `producer` todavía, es difícil verificar visualmente que el filtro funciona] → Mitigación: cubrir con fixtures/tests que incluyan pólizas de ambos canales, no depender de datos reales en desarrollo.
- [Mostrar "0 pólizas de producers" permanentemente hasta la Fase 2 podría confundir al admin pensando que algo está roto] → Mitigación: copy explicativo en la UI (ej. "Aún no hay ventas por productores afiliados") en vez de dejar el número en blanco o ambiguo.
