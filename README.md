# Asisto

Plataforma SaaS multi-tenant para cotización y comparación de seguros de viaje. Los productores (agentes de seguros) crean cotizaciones que se envían a múltiples proveedores en paralelo, comparan resultados y emiten pólizas al momento de la compra.

> **Nota:** El módulo de la aplicación se llama `Asisto` (definido en `config/application.rb`), aunque el directorio del repositorio sea `multicorizador`.

## Requisitos

- Ruby 3.3+
- Rails 8.0+
- SQLite3

No requiere Node.js — los assets se compilan con Propshaft + Importmap + TailwindCSS CLI.

## Instalación

```bash
# Clonar el repositorio
git clone <repo-url> && cd multicorizador

# Instalar dependencias
bundle install

# Crear base de datos y cargar datos de ejemplo
bin/rails db:create db:migrate db:seed
```

## Uso

```bash
# Iniciar servidor de desarrollo (web + TailwindCSS watcher + Solid Queue worker)
bin/dev
```

La aplicación estará disponible en `http://localhost:3000`.

### Credenciales por defecto (seeds)

| Rol          | Email                 | Password      |
|--------------|-----------------------|---------------|
| Super Admin  | admin@asisto.com      | password123   |
| Productor    | producer@asisto.com   | password123   |

### Crear un super admin

```bash
bin/rails admin:create EMAIL=admin@example.com PASSWORD=secret
```

## Comandos útiles

```bash
# Tests
bin/rails test                          # Todos los tests
bin/rails test test/models/user_test.rb # Un archivo específico
bin/rails test test/models/user_test.rb:42  # Un test por línea

# Linting y seguridad
bin/rubocop
bin/brakeman
```

## Arquitectura

### Stack

- **Backend:** Rails 8, SQLite3, Solid Queue (jobs)
- **Frontend:** Propshaft, Importmap, TailwindCSS 4, DaisyUI, Hotwire (Turbo + Stimulus)
- **Auth:** Devise
- **Forms:** SimpleForm con wrappers DaisyUI
- **Deploy:** Kamal

### Multi-tenancy

Cada request se scopa a una `Company` vía `acts_as_tenant`. Los super admins operan sin tenant.

### Roles y estados

**Roles:** `producer` (0), `super_admin` (1)

**Estados:** `pending` (0), `active` (1), `suspended` (2)

- Los productores se registran como `pending` y requieren aprobación de un super admin.
- Los super admins acceden a `/admin/*` y a Mission Control Jobs en `/jobs`.
- Los productores activos acceden a `/producer/*`.

### Ciclo de vida de cotizaciones

`draft` → `quoting` → `quoted` → `pending_payment` → `purchased` / `cancelled`

### Proveedores

Service objects en `app/services/insurance_providers/`. Cada proveedor implementa la interfaz de `BaseProvider` (`quote`, `purchase_url`, `parse_webhook`, `valid_webhook?`) y se registra en `REGISTRY` por slug.

## Deploy

Kamal (`bin/kamal`). Config en `config/deploy.yml`. El único secreto requerido es `RAILS_MASTER_KEY`. La base de datos SQLite se persiste vía Docker volume.
