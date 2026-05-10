# Flujo de Cotización

## Escenario A — Productor completa todo

```
[Productor] → Crea Traveler (o selecciona existente)
            → Completa Quote (datos del viaje)
            → Sistema dispara QuoteJob
            → Consulta APIs en paralelo (ProviderQuoteJob)
            → Quote status: quoting → quoted
            → Productor ve comparador de QuoteResults
            → Selecciona plan, envía link de pago al cliente
            → Cliente paga en sitio de aseguradora
            → Aseguradora emite póliza y envía webhook
            → Sistema crea Policy, calcula comisiones
            → Quote status: purchased
```

## Escenario B — Cliente completa sus datos vía link

```
[Productor] → Crea Quote con datos mínimos del viaje (sin traveler)
            → Genera Link público (expira en 7 días por defecto)
            → Envía link al cliente

[Cliente]   → Abre link (/public/quotes/:token)
            → Completa sus datos personales
            → Envía formulario
            → Quote se asocia al nuevo Traveler
            → Quote status: quoting
            → Sistema dispara QuoteJob (mismo flujo que A)
```

## Estados de Quote

| Estado | Significado | Editable | Eliminable |
|--------|-------------|----------|------------|
| `draft` | Armando la cotización | ✅ | ✅ |
| `client_pending` | Esperando que cliente llene datos (escenario B) | ✅ | ✅ |
| `quoting` | APIs siendo consultadas | ❌ | ❌ |
| `quoted` | Resultados listos | ✅ | ✅ |
| `pending_payment` | Link de pago generado | ✅ | ✅ |
| `purchased` | Póliza emitida (webhook recibido) | ❌ | ❌ |
| `cancelled` | Descartada por el productor | ❌ | ❌ |

**Regla de oro:** Una Quote con `status = purchased` es inmutable porque representa una transacción real. Una Quote `cancelled` es un soft-delete lógico.

## Comparador de Cotizaciones

Cuando `status = quoted`, el productor accede a la vista de comparación:

- Lista de `QuoteResult` con `status = success`
- Cada fila muestra: Aseguradora, Plan, Precio al cliente, Comisión estimada
- Botón "Seleccionar" genera el link de pago (redirige al checkout del proveedor)

## Link de Pago

El "enviar link al cliente" puede ser:
1. Un email con el link de checkout del proveedor (si la API lo permite).
2. Un mensaje manual del productor con el precio y las instrucciones.

La plataforma **no procesa pagos**. El cliente paga directamente a la aseguradora.

## Eliminar Cotizaciones

El productor puede eliminar una Quote siempre que `status != purchased`. La eliminación es `dependent: :destroy` en `QuoteResult` y `Link`.
