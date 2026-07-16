## 1. Pre-requisito

- [x] 1.1 Confirmar que `unify-direct-sale-flow` está implementado y `Policy` ya tiene el campo de canal (`sold_via`/`channel`) en `db/schema.rb` antes de arrancar este change. Confirmado: `t.string "sold_via", default: "direct", null: false` en `db/schema.rb`.

## 2. Modelo

- [x] 2.1 Agregar scopes a `Policy` para los dos canales (p. ej. `scope :direct, -> { where(sold_via: "direct") }` / `scope :producer_sold, -> { where.not(sold_via: "direct") }`), usando el nombre de columna real definido en `unify-direct-sale-flow`. Ya existían desde `unify-direct-sale-flow` (`app/models/policy.rb`).

## 3. Rutas y controller de admin

- [x] 3.1 Agregar `resources :policies, only: [:index, :show]` al namespace `admin` en `config/routes.rb`.
- [x] 3.2 Crear `app/controllers/admin/policies_controller.rb` con `before_action :authenticate_super_admin!`, `#index` (con filtro Ransack por canal) y `#show`. Se agregó `Policy.ransackable_attributes` (requerido por Ransack 4.x).
- [x] 3.3 Crear vistas `app/views/admin/policies/index.html.erb` y `show.html.erb`, siguiendo las convenciones Flowbite/Tabler ya usadas en el resto de `/admin` (`.table`, `.badge`, `.stat`).

## 4. Dashboard

- [x] 4.1 Reemplazar `@total_policies = 0` en `Admin::DashboardController#index` por conteos reales usando los scopes de la tarea 2.1 (total directo, total producer).
- [x] 4.2 Actualizar `app/views/admin/dashboard/index.html.erb`: reemplazar la tarjeta única "Pólizas Emitidas" por dos tarjetas (Ruka directo / Producers), con copy explicativo cuando el total de producers sea 0 (ver Risks en design.md).
- [x] 4.3 Enlazar las tarjetas del dashboard al listado filtrado correspondiente en `admin/policies`.

## 5. Tests

- [x] 5.1 Fixtures de `Policy` con ambos canales (`direct` y `producer`) para poder testear el filtro sin depender de datos reales. (Se agregó también una segunda company/tenant y producer para probar cross-tenant.)
- [x] 5.2 Test de controller: `admin/policies#index` lista pólizas de múltiples companies/tenants (confirma que el tenant `nil` del admin no filtra nada).
- [x] 5.3 Test de controller: filtro por canal devuelve solo las pólizas correspondientes.
- [x] 5.4 Test de controller: un usuario `producer` no puede acceder a `admin/policies`.
- [x] 5.5 Test de `Admin::DashboardController#index`: los totales por canal coinciden con los datos reales de las fixtures.

## 6. Regresión

- [x] 6.1 Correr `bin/rails test` y `bin/rubocop`. Suite verde (11/11, corrida repetida con seeds distintas para descartar order-dependence). Se encontró y arregló un bug de aislamiento de tests: la fixture `demo_quote` (AEP→COR) colisionaba con los mismos códigos usados en un test de `unify-direct-sale-flow`, haciendo que `find_by!` matcheara el registro equivocado — se corrigió usando el token del redirect en vez de origen/destino.
- [x] 6.2 Prueba manual en `bin/dev`: crear pólizas de ambos canales (o solo directo si producer aún no existe), verificar dashboard y listado filtrado en `/admin`. Verificado con `bin/dev` real: dashboard mostró "Pólizas Ruka Directo: 1" / "Pólizas Producers: 1", el listado `/admin/policies` mostró ambas con su badge de canal, el filtro `?q[sold_via_eq]=direct` devolvió solo la directa, y `/admin/policies/:id` (show) renderizó bien. Datos de prueba limpiados de la DB de desarrollo al terminar.
