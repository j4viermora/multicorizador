## 1. Medir el punto de partida

- [ ] 1.1 Medir el tiempo de fan-out completo con los cuatro fakes y sus latencias actuales, para tener el "antes" contra el cual comparar
- [ ] 1.2 Confirmar que `OmintProvider` no devuelve vigencia y que los fakes la devuelven dentro de `raw_response`, que es lo que motiva la columna nueva

## 2. Vigencia de los resultados

- [ ] 2.1 Migración: agregar `valid_until` (datetime, nullable) a `quote_results`
- [ ] 2.2 En `ProviderQuoteJob`, persistir `valid_until` desde la respuesta del proveedor cuando venga
- [ ] 2.3 Aplicar una vigencia por defecto configurable cuando el proveedor no la informa, con un valor conservador
- [ ] 2.4 Agregar a `QuoteResult` un scope de resultados vigentes, para no repetir la comparación de fechas en cada consulta
- [ ] 2.5 Test: un proveedor que informa vigencia la persiste; uno que no, recibe el default
- [ ] 2.6 Test: el scope de vigentes excluye los vencidos e incluye los que aún no vencieron

## 3. Huella de búsqueda

- [ ] 3.1 Migración: agregar `search_fingerprint` (string) a `quotes` con índice compuesto `(company_id, search_fingerprint, created_at)`
- [ ] 3.2 Calcular el fingerprint en `Quote` antes de guardar, normalizando: origen y destino sin espacios y en minúsculas, edades a entero y ordenadas, fechas en ISO
- [ ] 3.3 Test de igualdad: mismas edades en distinto orden producen el mismo fingerprint
- [ ] 3.4 Test de igualdad: origen y destino con distinta capitalización o espacios producen el mismo fingerprint
- [ ] 3.5 Test de desigualdad: cambiar edades manteniendo la cantidad de viajeros produce fingerprints distintos
- [ ] 3.6 Test de desigualdad: cambiar fecha de regreso, `trip_type`, cantidad de viajeros, origen o destino produce fingerprints distintos
- [ ] 3.7 Test: dos empresas con parámetros idénticos no colisionan al buscar, porque `company_id` acota la consulta

## 4. Reutilización de búsquedas

- [ ] 4.1 Agregar la ventana de caché como configuración, con un default en minutos y la posibilidad de ponerla en cero para desactivar
- [ ] 4.2 En `QuoteJob`, antes de encolar, buscar la cotización equivalente más reciente del mismo tenant dentro de la ventana y con resultados vigentes
- [ ] 4.3 Copiar sus `QuoteResult` exitosos a la cotización nueva y dejarla en `quoted`, sin encolar `ProviderQuoteJob`
- [ ] 4.4 Excluir de la copia los resultados en `error`, y descartar como candidata una búsqueda previa sin ningún resultado exitoso
- [ ] 4.5 No reutilizar parcialmente: si algún resultado de la búsqueda previa venció, cotizar de nuevo contra los proveedores
- [ ] 4.6 Registrar en la cotización que se resolvió por reutilización
- [ ] 4.7 Test: búsqueda repetida dentro de la ventana no encola ningún `ProviderQuoteJob` y queda en `quoted` con los mismos resultados
- [ ] 4.8 Test: búsqueda repetida fuera de la ventana sí encola
- [ ] 4.9 Test: con la ventana en cero nunca se reutiliza
- [ ] 4.10 Test: una búsqueda de otra empresa con parámetros idénticos no se reutiliza
- [ ] 4.11 Test: no se copian los resultados en `error` de la búsqueda previa
- [ ] 4.12 Test: si los resultados previos vencieron, se cotiza de nuevo aunque estén dentro de la ventana

## 5. No vender lo vencido

- [ ] 5.1 En `Public::LandingController#complete_purchase!`, validar la vigencia del resultado elegido antes de llamar a `PolicyIssuer`
- [ ] 5.2 Rechazar la compra con un mensaje que explique que la cotización expiró y ofrezca volver a cotizar
- [ ] 5.3 Dejar `WebhookProcessorJob` sin validación de vigencia, con un comentario que explique por qué la asimetría es deliberada
- [ ] 5.4 Test: comprar sobre un resultado vigente emite la póliza
- [ ] 5.5 Test: comprar sobre un resultado vencido no emite ninguna póliza e informa la expiración
- [ ] 5.6 Test: un webhook sobre un resultado vencido sí emite la póliza
- [ ] 5.7 Test: los resultados anteriores a la migración, sin `valid_until`, no bloquean una compra en curso

## 6. Validación end-to-end

- [ ] 6.1 Cotizar dos veces la misma búsqueda y verificar que la segunda es inmediata y no llama a los proveedores
- [ ] 6.2 Comparar el tiempo de la segunda búsqueda contra la medición de la tarea 1.1
- [ ] 6.3 Verificar que la comparación de resultados se ve igual en ambos casos, en la pantalla del productor y en la pública
- [ ] 6.4 Verificar que cambiar una sola edad fuerza una cotización nueva
- [ ] 6.5 Correr `bin/rails test` y `bin/rubocop`

## 7. Cierre

- [ ] 7.1 Elegir el default de la ventana de caché y dejar registrado que es una decisión provisoria a ajustar con datos reales
- [ ] 7.2 Elegir la vigencia por defecto para proveedores que no la informan, con criterio conservador mientras Omint siga sin validar
- [ ] 7.3 Decidir si la pantalla debe avisar que los resultados provienen de una búsqueda previa, o si se mantiene indistinguible
- [ ] 7.4 Dejar anotado que el caché conviene habilitarse primero solo con proveedores fake, porque reutilizar `external_quote_id` contra un proveedor real puede hacer que rechace la compra
- [ ] 7.5 Confirmar que con la ventana en cero el sistema se comporta exactamente como antes de este change
