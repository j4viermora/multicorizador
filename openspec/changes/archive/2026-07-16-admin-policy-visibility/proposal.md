## Why

El panel de admin no tiene hoy ninguna forma de ver las pólizas emitidas: `Admin::DashboardController#index` trae `@total_policies = 0` hardcodeado (comentario `# Policy.count cuando exista`, aunque `Policy` ya existe en el schema) y no existe ningún `admin/policies` en las rutas. Los dueños de Ruka necesitan poder ver, desde el admin, cuánto se emitió directamente por Ruka y cuánto por productores afiliados, para tener visibilidad del negocio incluso antes de que exista el cálculo de comisiones.

Este change depende de que exista el campo de canal en `Policy` (`sold_via`/`channel`) introducido por el change `unify-direct-sale-flow`; hasta que ese campo no esté implementado, no hay forma de distinguir "directo" de "producer" en los datos.

## What Changes

- Agregar un namespace `admin/policies` (listado, con filtro por canal — directo / producer) para que el admin pueda ver todas las pólizas emitidas, sin importar la company/tenant de origen.
- Reemplazar el `@total_policies = 0` hardcodeado del dashboard de admin por conteos reales: total emitido por Ruka (directo) y total emitido por producers (afiliados), usando el campo de canal de `Policy`.
- El listado y los totales deben funcionar aunque hoy el canal "producer" esté siempre vacío (no hay producers reales vendiendo por link propio todavía) — la pantalla se construye ahora para no repetir trabajo cuando la Fase 2 (link de producer) tenga datos reales.

## Capabilities

### New Capabilities
- `admin-policy-visibility`: el admin puede listar, filtrar por canal, y ver totales agregados de las pólizas emitidas en todo el sistema (directas y vía producer), sin necesidad de cambiar de tenant.

### Modified Capabilities
(ninguna — no se modifican requisitos de `direct-sale-flow`, solo se consume el campo de canal que ese change introduce)

## Impact

- **Código afectado**: `app/controllers/admin/dashboard_controller.rb`, `app/views/admin/dashboard/index.html.erb`, nuevo `app/controllers/admin/policies_controller.rb`, nuevas vistas `app/views/admin/policies/*`, `config/routes.rb` (namespace `admin`).
- **Dependencia dura**: requiere que `Policy` tenga el campo de canal (`sold_via`/`channel`) del change `unify-direct-sale-flow` ya implementado. No aplicar este change antes que ese.
- **Sin impacto en schema propio**: este change no agrega columnas nuevas, solo consume las que ya deja `unify-direct-sale-flow`.
- **Sin impacto en `acts_as_tenant`**: el admin ya opera con `ActsAsTenant.current_tenant = nil` (ver `ApplicationController#set_current_tenant`), por lo que las queries de `Policy` ya devuelven registros de todas las companies sin scoping adicional — no se requiere ningún cambio de tenancy para este change.
