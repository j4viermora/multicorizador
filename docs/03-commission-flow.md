# Flujo de Comisiones

## Principio

Las comisiones se calculan **al momento de la emisión de la póliza** (cuando llega el webhook del proveedor), no al momento de la cotización. Esto es porque el precio final puede variar entre cotización y emisión.

## Contratos de Comisión

`CommissionContract` define las tasas por proveedor:

- **Default:** `producer_id = NULL` → aplica a todos los productores de ese proveedor.
- **Específico:** `producer_id = X` → anula el default para ese productor.
- Resolución: busca específico primero, luego default.

## Fórmulas

```
provider_commission = total * provider_commission_rate
producer_commission = provider_commission * producer_share_rate
platform_commission = provider_commission - producer_commission
```

## Ejemplo Paso a Paso

**Datos:**
- Prima total: $100.00
- `provider_commission_rate`: 40% (0.40)
- `producer_share_rate`: 50% (0.50)

**Cálculo:**
1. `provider_commission = $100.00 * 0.40 = $40.00` → Aseguradora nos paga $40.
2. `producer_commission = $40.00 * 0.50 = $20.00` → Nosotros le damos $20 al productor.
3. `platform_commission = $40.00 - $20.00 = $20.00` → Nosotros nos quedamos con $20.

**Resumen:**
| Entidad | Monto |
|---------|-------|
| Aseguradora recibe | $100.00 (del cliente) |
| Aseguradora paga a plataforma | $40.00 |
| Plataforma paga a productor | $20.00 |
| Plataforma se queda con | $20.00 |

## Visualización para el Productor

En el comparador de cotizaciones, el productor ve:

| Aseguradora | Plan | Precio cliente | Tu comisión estimada |
|-------------|------|----------------|----------------------|
| Aseguradora A | Básico | $100.00 | $20.00 (20%) |

Nota: el 20% mostrado es el resultado de aplicar las dos tasas (40% × 50%).

## Estados de Comisión

Una `Policy` tiene `producer_commission_status`:

- `pending`: Póliza emitida, comisión aún no facturada.
- `invoiced`: El productor generó su factura mensual incluyendo esta póliza.
- `paid`: El super admin marcó la factura como pagada.

## Facturación Consolidada (Mensual)

El productor puede seleccionar múltiples pólizas en estado `pending` y generar una `ProducerInvoice` única. Esto:
1. Crea la factura con el total de comisiones.
2. Cambia el estado de las pólizas a `invoiced`.
3. Bloquea esas pólizas para otra factura.

El super admin luego marca la `ProducerInvoice` como `paid` y todas sus pólizas pasan a `paid`.

## Facturación a Aseguradoras

El super admin genera manualmente `PlatformInvoice` por proveedor y período, agrupando las pólizas emitidas. Esto es puramente para tracking interno; la plataforma no emite facturas electrónicas.
