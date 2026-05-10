# Landing Pública de Cotización por Empresa

## Resumen

Cada empresa (Company) tiene una **página pública de cotización** accesible sin autenticación. Los clientes finales pueden cotizar su seguro de viaje directamente desde esta URL, similar a cómo funciona `sistemacnet.com/vendors/:nombre`.

## URLs

| URL | Descripción |
|-----|-------------|
| `/cotizar/:slug` | Formulario público de cotización |
| `/cotizar/:slug?ref=ID` | Idem, atribuida a un productor específico |
| `/cotizar/:slug/gracias?token=TOKEN` | Página de confirmación post-cotización |

### Ejemplos

```
https://asisto.com/cotizar/demo-corp
https://asisto.com/cotizar/demo-corp?ref=42
```

## Cómo funciona el slug

- Cada `Company` tiene un campo `slug` único (ej: `demo-corp`)
- Se genera automáticamente al crear la empresa a partir del nombre con `parameterize` (ej: "Mi Empresa SA" → `mi-empresa-sa`)
- Si ya existe un slug igual, se agrega un sufijo numérico (`mi-empresa-sa-2`)
- El slug solo admite letras minúsculas, números y guiones
- Se puede cambiar manualmente desde el admin

### Ejemplo de generación

| Nombre de empresa | Slug generado |
|---|---|
| Demo Corp | `demo-corp` |
| Seguros Pérez & Asociados | `seguros-perez-asociados` |
| Travel Pro | `travel-pro` |

## Flujo del cliente

1. El cliente accede a `/cotizar/demo-corp`
2. **Paso 1**: Completa datos del viaje (origen, destino, fechas, tipo, cantidad de pasajeros)
3. **Paso 2**: Ingresa edad de cada pasajero + sus datos personales (nombre, email, teléfono, documento)
4. Click en "Cotizar ahora"
5. Se crea la `Quote` asociada a la `Company` y al productor (por defecto el primer productor activo, o el indicado por `?ref=ID`)
6. Se lanza `QuoteJob` para consultar proveedores
7. Se redirige a `/cotizar/:slug/gracias` con el resumen de la cotización

## Atribución al productor (`?ref=`)

El parámetro `ref` permite que cada productor tenga su propia URL personalizada para compartir:

```
/cotizar/demo-corp?ref=42   → La cotización se asigna al productor con ID 42
/cotizar/demo-corp           → Se asigna al primer productor activo de la empresa
```

Si el `ref` apunta a un usuario inexistente o inactivo, se usa el productor por defecto.

**Caso de uso**: Un productor comparte `asisto.com/cotizar/demo-corp?ref=42` en su WhatsApp/redes sociales. Todas las cotizaciones que entren por ese link se le atribuyen automáticamente.

## Diferencias con el formulario interno (productor)

| Aspecto | Form interno (`/producer/quotes/new`) | Landing pública (`/cotizar/:slug`) |
|---|---|---|
| Autenticación | Requiere login de productor | Sin autenticación |
| Viajero existente | Puede seleccionar de su cartera | Siempre crea nuevo |
| Datos del viajero | Opcionales (puede agregar después) | Nombre, email requeridos |
| Lenguaje | Formal ("Datos del viaje") | Cercano ("¿A dónde viajás?") |
| Branding | Navbar de Asisto | Nombre de la empresa + "Powered by Asisto" |
| `created_by` | `"producer"` | `"client"` |

## Archivos involucrados

```
config/routes.rb                              → Rutas /cotizar/:slug
app/controllers/public/landing_controller.rb  → Controller
app/views/public/landing/show.html.erb        → Formulario wizard
app/views/public/landing/thanks.html.erb      → Página de confirmación
app/views/layouts/public.html.erb             → Layout público
app/models/company.rb                         → Slug + validaciones
db/migrate/*_add_slug_to_companies.rb         → Migración
```

## Flujo actual (búsqueda sin DB)

La cotización pública es una **búsqueda**, no una transacción. No se crean registros en la DB hasta que el cliente decida comprar.

```
Form (2 pasos) → POST → consulta proveedores sincrónicamente → muestra comparación de resultados
```

### Paso 1: Datos del viaje
- Origen y destino (autocomplete de países/regiones)
- Fechas de salida y regreso
- Tipo de viaje y cantidad de pasajeros

### Paso 2: Contacto + edades
- Edad de cada pasajero (necesario para calcular precio)
- Email (requerido) y WhatsApp (opcional) — para contactar al cliente

### Página de resultados
- Cards comparativas por proveedor, ordenados por precio
- Badge "Mejor precio" en el más económico
- Coberturas detalladas por plan
- Botón "Comprar este plan" (placeholder, futuro)

### Archivos clave del flujo de búsqueda
```
app/models/quote_search.rb                                  → Value object (no DB)
app/services/quote_search_service.rb                         → Orquestador sincrónico
app/services/insurance_providers/assist_card_fake.rb          → Proveedor fake 1
app/services/insurance_providers/universal_assistance_fake.rb → Proveedor fake 2
app/services/insurance_providers/travel_ace_fake.rb           → Proveedor fake 3
app/views/public/landing/results.html.erb                    → Página de comparación
```

## Pendientes / Ideas futuras

- [ ] **Panel de búsquedas**: Guardar cada búsqueda del cliente (origen, destino, fechas, edades, email, WhatsApp) en una tabla `searches` o similar. Permite al productor ver qué buscan sus clientes, destinos más populares, demanda por fechas, leads por contactar. No bloquea el flujo actual — se puede hacer como un `INSERT` asincrónico después de mostrar resultados.
- [ ] **Flujo de compra**: Al hacer click en "Comprar este plan", recopilar datos completos del viajero (nombre, documento, etc.), crear `Quote` + `QuoteResult` + `Policy` en la DB, y redirigir al checkout del proveedor.
- [ ] Permitir personalizar colores/logo por empresa
- [ ] SEO meta tags dinámicos por empresa
- [ ] Widget embebible (iframe) para que productores lo pongan en su web
- [ ] QR code auto-generado con la URL del productor
