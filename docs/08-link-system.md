# Sistema de Links Compartidos

## Propósito

El sistema de `Link` permite compartir recursos de la plataforma (cotizaciones, documentos, etc.) mediante URLs con tokens únicos, expiración, trackeo de accesos y revocación.

## Casos de uso

1. **Link de cotización pública:** Productor genera un link para que el cliente complete sus datos personales (Escenario B).
2. **Link de pago:** (futuro) Redirigir al checkout del proveedor.
3. **Link de documento:** (futuro) Compartir póliza o comprobante.

## Atributos

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `token` | string | Identificador único de 32 caracteres. Usado en la URL. |
| `purpose` | string | Tipo de link: `quote_share`, `payment`, `document`. |
| `expires_at` | datetime | Fecha de expiración. `nil` = nunca expira. |
| `access_count` | integer | Cuántas veces se accedió. |
| `last_accessed_at` | datetime | Último acceso. |
| `status` | string | `active`, `expired`, `revoked`. |

## Generación de token

```ruby
SecureRandom.urlsafe_base64(24) # ~32 caracteres, URL-safe
```

## URL pública

```
https://asisto.com/public/quotes/:token
```

## Flujo de acceso

```
[Cliente] → GET /public/quotes/:token
        → Busca Link por token
        → ¿Link existe? → 404
        → ¿Status revoked? → 403
        → ¿Expirado? → marca status expired, responde 410 Gone
        → Incrementa access_count, actualiza last_accessed_at
        → Muestra formulario/Contenido
```

## Expiración

- Por defecto: 7 días desde la creación.
- Configurable al crear el link: `quote.create_share_link!(expires_in: 3.days)`.
- Un link expirado puede ser regenerado creando uno nuevo.

## Revocación

El productor puede revocar un link desde su panel:
```ruby
link.revoke! # status → revoked
```

Un link revocado no puede ser reactivado. Se debe crear uno nuevo.

## Relación con Quote

```ruby
class Quote
  has_many :links, dependent: :destroy

  def active_share_link
    links.quote_share.active.where("expires_at > ? OR expires_at IS NULL", Time.current).first
  end
end
```

## Trackeo

Cada acceso se registra con:
- `access_count` (incremental)
- `last_accessed_at` (timestamp)

Para trackeo avanzado (IP, user agent), se recomienda una tabla `LinkAccessLog` en el futuro.

## Seguridad

- Tokens son criptográficamente aleatorios (no predecibles).
- No contienen información sensible (solo un ID opaco).
- Los links no requieren autenticación (son públicos).
- Si un link se filtra, se puede revocar y regenerar.
