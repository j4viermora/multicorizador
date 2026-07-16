# Arquitectura de Ruka — Multicotizador de Seguros de Viaje

## Visión General

Ruka es una plataforma multi-tenant que permite a productores de seguros cotizar, comparar y gestionar pólizas de viaje de múltiples aseguradoras a través de un único panel. El super admin gestiona proveedores, comisiones y finanzas globales.

## Stack Tecnológico

- **Framework:** Ruby on Rails 8.0
- **Base de datos:** SQLite3 (MVP) → PostgreSQL (escala)
- **Autenticación:** Devise
- **Multi-tenancy:** `acts_as_tenant` (scoping por `Company`)
- **Dinero:** `money-rails` con `Money.default_currency` configurado por `Company`
- **CSS:** TailwindCSS + DaisyUI
- **JS:** Hotwire (Turbo + Stimulus) via Importmap
- **Jobs:** Solid Queue (DB-backed)
- **Email:** Resend (prod) / letter_opener (dev)
- **Rich text:** Lexxy
- **Despliegue:** Kamal

## Decisiones de Diseño Clave

### 1. Multi-tenancy con Company

Todo modelo de negocio (`Traveler`, `Quote`, `QuoteResult`, `Policy`, `Link`) es tenant-scoped vía `acts_as_tenant :company`. Los modelos globales (`Provider`, `InsurancePlan`) no tienen tenant.

**Excepción:** Los usuarios con `role: super_admin` no tienen `company` asignada (o tienen una dummy) y operan sin tenant. El `ApplicationController` maneja este caso en `set_current_tenant`.

### 2. SQLite para el MVP

Se usa SQLite para acelerar el desarrollo inicial. El esquema es 100% compatible con ActiveRecord, por lo que la migración a PostgreSQL consiste únicamente en cambiar `database.yml` y adaptar el uso de `jsonb` → `json` en SQLite (ActiveRecord ya abstrae esto).

### 3. money-rails

Todas las cantidades monetarias usan `monetize` (campos `_cents` + `_currency`). La moneda por defecto se setea en cada request según `current_user.company.currency`. Esto permite que cada `Company` opere en su moneda (ARS, USD, etc.).

### 4. Patrón Strategy para Proveedores

Cada aseguradora se integra mediante una clase que hereda de `InsuranceProviders::BaseProvider`, registrada en `InsuranceProviders::REGISTRY`. Esto permite agregar nuevas aseguradoras sin modificar el código core.

### 5. Async por defecto

Toda operación que toque APIs externas (cotización, webhooks) se ejecuta vía Solid Queue para no bloquear requests HTTP.

### 6. Links Compartidos con Expiración

El sistema de links (`Link`) permite compartir cotizaciones mediante tokens únicos con expiración, trackeo de accesos y revocación. Es agnóstico al propósito (cotización, pago, documento).

## Convenciones de Código

- Idioma del código: inglés (modelos, variables, métodos)
- Idioma de la UI: español (vistas, flash messages, I18n)
- Controladores agrupados por namespace: `Admin::`, `Producer::`, `Public::`
- Servicios bajo `app/services/insurance_providers/`
- Jobs bajo `app/jobs/`
- Validaciones de presencia siempre con `presence: true`
- Enums definidos con strings para legibilidad en DB
