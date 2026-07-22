# Ruka

Plataforma SaaS multi-tenant para cotización y comparación de seguros de viaje. Los productores (agentes de seguros) crean cotizaciones que se envían a múltiples proveedores en paralelo, comparan resultados y emiten pólizas al momento de la compra.

> **Nota:** El módulo de la aplicación se llama `Ruka` (definido en `config/application.rb`), aunque el directorio del repositorio sea `multicorizador`.

## Requisitos

- Ruby 3.3+
- Rails 8.0+
- Docker (para MariaDB)

No requiere Node.js — los assets se compilan con Propshaft + Importmap + TailwindCSS CLI.

## Instalación

```bash
# Clonar el repositorio
git clone <repo-url> && cd multicorizador

# Instalar dependencias
bundle install

# Levantar MariaDB (docker-compose la expone en el puerto 3307)
docker compose up -d

# Crear base de datos y cargar datos de ejemplo
bin/rails db:prepare
bin/rails db:seed
```

> **MariaDB, no SQLite.** Desarrollo y test corren sobre MariaDB 11.4 vía `docker-compose.yml`; producción usa `APP_DATABASE_URL`. Volver a SQLite rompe el esquema: no distingue `INTEGER` de `BIGINT`, así que al dumpear `db/schema.rb` reescribe las foreign keys y `db:prepare` falla en el deploy. Ver los detalles en [CLAUDE.md](CLAUDE.md).

## Uso

```bash
# Iniciar servidor de desarrollo (web + TailwindCSS watcher + Solid Queue worker)
bin/dev
```

La aplicación estará disponible en `http://localhost:3000`.

### Usuarios de prueba (seeds)

Todos usan la misma contraseña: **`password123`**. Son credenciales de desarrollo, creadas por `db:seed`; no existen en producción.

| Rol         | Email               | Empresa    | Entra a       | Para qué sirve                                          |
|-------------|---------------------|------------|---------------|---------------------------------------------------------|
| Super Admin | `admin@ruka.com`    | Ruka Admin | `/admin/*`    | Proveedores, planes, usuarios, pólizas y `/jobs`         |
| Productor   | `producer@ruka.com` | Demo Corp  | `/producer/*` | Cotizar y comparar como agente de una agencia            |
| Productor   | `ventas@ruka.com`   | Ruka       | `/producer/*` | Vendedor in-house, para probar el flujo de venta directa  |

Un super admin **no** entra a `/producer/*` ni viceversa: cada rol está restringido a su namespace.

### Landings públicas (sin login)

Cada empresa tiene su cotizador público en `/cotizar/:slug`:

| Empresa    | URL                    |
|------------|------------------------|
| Ruka       | `/cotizar/ruka`        |
| Demo Corp  | `/cotizar/demo-corp`   |

Los resultados de una cotización pública quedan en `/cotizar/:slug/resultados/:token`, accesibles sin sesión mediante el token.

### Proveedores de prueba

Los seeds dejan activos cuatro proveedores fake que cotizan con datos estáticos calculados (tarifa diaria × días × viajeros, con recargo para 65+). Tres de ellos devuelven una escala de cuatro planes cada uno:

| Proveedor              | Planes | Notas                                        |
|------------------------|--------|----------------------------------------------|
| Assist Card            | 4      | El más caro de los tres                       |
| Universal Assistance   | 4      |                                               |
| Travel Ace             | 4      | El más económico                              |
| Example Seguros        | 1      | No devuelve coberturas; sirve de caso límite  |

**Omint** queda sembrado como `inactive` a propósito: es el único proveedor real y espera validación contra su ambiente de test. Su `client_secret` se lee de `OMINT_CLIENT_SECRET`. Se puede activar desde `/admin/providers` con el toggle del listado, sin tocar su configuración.

Solo los proveedores `active` reciben cotizaciones. Si los apagás todos, las cotizaciones quedan sin resultados y la pantalla lo avisa.

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

- **Backend:** Rails 8, MariaDB (`mysql2`), Solid Queue / Cache / Cable sobre la base principal
- **Frontend:** Propshaft, Importmap, TailwindCSS 4, Flowbite, Hotwire (Turbo + Stimulus)
- **Auth:** Devise
- **Forms:** SimpleForm con wrappers Flowbite
- **Iconos:** Tabler Icons
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

Kamal (`bin/kamal`). Config en `config/deploy.yml`.

Variables requeridas:

- `RAILS_MASTER_KEY`
- `APP_DATABASE_URL` — deliberadamente **no** se llama `DATABASE_URL`: Rails auto-fusiona esa variable en la config primaria y deja que el esquema de la URL pise el adapter, lo que rompe con URLs `mariadb://`.

Solid Queue corre dentro de Puma (`SOLID_QUEUE_IN_PUMA=true`), así que comparte el pool de conexiones con los threads web. Si subís `threads` en `config/queue.yml`, subí en la misma medida el `+5` del `pool` en `config/database.yml`, o Solid Queue no arranca y se lleva puesto el servidor web.
