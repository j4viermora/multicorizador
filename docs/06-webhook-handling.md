# Manejo de Webhooks

## Endpoints

Cada proveedor envía webhooks a un endpoint único:

```
POST /webhooks/:provider_slug
```

Ejemplo:
```
POST /webhooks/example_seguros
POST /webhooks/mi_seguro
```

## Autenticación

Cada proveedor configura un token único en `Provider#config`:

```json
{
  "webhook_token": "sekret_token_123"
}
```

El header de autenticación puede variar por proveedor:
- `X-Provider-Token`
- `Authorization: Bearer ...`
- Firma HMAC en `X-Signature`

Cada clase de proveedor implementa `valid_webhook?(request)` para validar según su esquema.

## Flujo de procesamiento

```
[Proveedor] → POST /webhooks/:slug
            → WebhooksController#receive
            → valida autenticación (provider.valid_webhook?)
            → encola WebhookProcessorJob
            → responde 202 Accepted inmediatamente

[Worker]    → WebhookProcessorJob.perform
            → busca QuoteResult por external_quote_id
            → parsea payload con provider.parse_webhook
            → crea Policy con comisiones calculadas
            → actualiza Quote a purchased
```

## Idempotencia

Los webhooks pueden llegar duplicados. Para prevenir pólizas duplicadas:

1. **Buscar** `Policy` existente por `policy_number` antes de crear.
2. Si ya existe, ignorar el webhook y retornar `200 OK`.
3. Usar `find_or_create_by` con `policy_number` como clave única lógica.

## Seguridad

- Siempre validar el token/firma antes de procesar.
- Nunca exponer datos sensibles en logs (usar `Rails.filter` para campos como `document`, `credit_card`).
- Responder `202 Accepted` rápido para no hacer timeout al proveedor.
- Encolar el procesamiento real para no bloquear el request.

## Payload de ejemplo (genérico)

```json
{
  "event": "policy.issued",
  "quote_id": "ext-quote-123",
  "policy": {
    "number": "POL-987654",
    "issued_at": "2024-05-10T14:30:00Z",
    "start_date": "2024-06-01",
    "end_date": "2024-06-15",
    "premium_cents": 10000,
    "total_cents": 10000,
    "currency": "USD",
    "document_url": "https://aseguradora.com/polizas/987654.pdf"
  }
}
```

Cada proveedor normaliza esto a través de `parse_webhook`.

## Manejo de errores en webhook

Si el webhook no puede procesarse (ej: `quote_id` no encontrado, payload inválido):

1. Loggear el error con el payload completo.
2. No responder con error 5xx al proveedor (evita reintentos agresivos).
3. Responder `202 Accepted` y registrar el fallo internamente.
4. Alertar al super admin vía email o dashboard.

## Logging

Todos los webhooks se loggean con:
- `provider_slug`
- `timestamp`
- `headers` (filtrados)
- `payload` (completo)
- `processing_status`: `success`, `error`, `duplicate`
