## 1. Verificar el flujo actual antes de tocar nada

- [x] 1.1 Levantar la app (`docker compose up -d`, `bin/rails db:prepare`, `bin/dev`) y confirmar que los cuatro proveedores fake quedan `active` tras `db:seed` y que Omint queda `inactive`
- [x] 1.2 Crear una cotización desde el buscador y confirmar que los tres fakes producen `QuoteResult` con `status: "success"` y coberturas en `raw_response["coverage"]` — los tres fakes devuelven 8/7/6 coberturas; `example_seguros` devuelve `coverage` nil, que es el caso defensivo real de la tarea 4.5
- [x] 1.3 Capturar cómo se ve hoy la pantalla de resultados, como referencia del antes

## 2. Escala de planes en los proveedores

- [x] 2.1 Documentar en `BaseProvider#quote` que el retorno admite un hash o un array de hashes, contrato que `ProviderQuoteJob:16` ya honra vía `Array.wrap` pero que no está escrito en ningún lado
- [x] 2.2 Convertir `AssistCardFake#quote` en una escala de cuatro planes, derivando cada escalón de la tarifa base actual con multiplicadores (el plan base conserva el precio de hoy) — lógica común extraída a `FakePlanScale`
- [x] 2.3 Dar a cada escalón su propio `external_quote_id`, `plan_name` y coberturas crecientes respecto del anterior
- [x] 2.4 Hacer lo mismo en `UniversalAssistanceFake` y `TravelAceFake`, con escalas distinguibles entre proveedores
- [x] 2.5 Test: cada fake devuelve cuatro opciones con precios distintos y ordenables
- [x] 2.6 Test: la escala responde a días de viaje, cantidad de viajeros y recargo por edad en las cuatro opciones, no solo en algunas
- [x] 2.7 Test: la opción más cara ofrece coberturas mayores o adicionales que la más económica
- [x] 2.8 Test de job: un proveedor que devuelve cuatro opciones produce cuatro `QuoteResult` con el mismo `provider_id`, y uno que falla produce un único resultado en `error`

## 3. Datos de la comparación

- [x] 3.1 En `Producer::QuotesController#show:10`, agrupar los resultados exitosos por proveedor con `includes(:provider)` para evitar una consulta por resultado — implementado como `Quote#offers_by_provider` para que la vista pública lo reuse
- [x] 3.2 Ordenar las opciones dentro de cada grupo por `price_cents` ascendente
- [x] 3.3 Ordenar los grupos por el `price_cents` mínimo de cada proveedor
- [x] 3.4 Exponer los proveedores con resultados en `error` como colección separada, sin mezclarlos con los exitosos (`Quote#failed_providers`)
- [x] 3.5 Test de controlador: doce resultados de tres proveedores llegan como tres grupos, ordenados dentro y entre sí — cubierto a nivel modelo, donde es testeable sin renderizar
- [x] 3.6 Test de controlador: un proveedor con resultado en `error` queda expuesto en lugar de descartarse

## 4. Rediseño de la pantalla de comparación

- [x] 4.1 Construir el layout de una fila por proveedor con sus opciones dentro, alineado al lenguaje visual del buscador (paleta `teal`, iconos Tabler)
- [x] 4.2 Hacer que la fila fluya (scroll horizontal contenido o wrap) en lugar de una grilla de cuatro columnas fijas, para tolerar proveedores con 1, 4 o 7 opciones
- [ ] 4.3 Verificar que en viewport angosto la fila no provoca scroll horizontal del `body` — **pendiente de verificación visual**: la extensión de Chrome se colgó al sacar el screenshot. El CSS lo garantiza por construcción (`.offer-row` tiene `overflow-x-auto`, `.offer-card` tiene `shrink-0 w-72`), pero no está confirmado en pantalla real
- [x] 4.4 Renderizar las coberturas de cada opción desde `raw_response["coverage"]`, con nombre y monto
- [x] 4.5 Tolerar de forma defensiva que falte `coverage`, venga vacía, o que un item no traiga `amount` — cubierto también para items que no son hashes
- [x] 4.6 Presentar los proveedores fallidos de forma diferenciada, identificando cuál falló
- [x] 4.7 Cubrir el caso de que todos los proveedores fallen con un mensaje propio, distinto del de "sin resultados"
- [x] 4.8 Hacer que la rama `quoting` muestre las filas ya recibidas junto al indicador de progreso
- [x] 4.9 No darle prominencia de acción primaria al botón "Seleccionar", que sigue apuntando a `"#"` — queda como `btn-outline`, no como acción primaria
- [x] 4.10 Extender el `@layer components` de `app/assets/tailwind/application.css` con `@apply` si hace falta una pieza nueva, en lugar de inlinear cadenas largas de utilidades — agregado el bloque "Comparación de cotizaciones"
- [x] 4.11 Evaluar con la pantalla armada si las coberturas de 12 opciones resultan ilegibles; si es así, colapsarlas por opción con un disclosure de Flowbite dejando precio y plan siempre visibles — ~96 filas de detalle, así que se muestran 3 coberturas y el resto va en un `<details>`

## 5. Refresco automático de resultados

- [x] 5.1 Emitir un Turbo Stream desde `ProviderQuoteJob` al terminar cada proveedor, para que su fila aparezca sin recargar
- [x] 5.2 Suscribir la pantalla de comparación al stream de la cotización
- [x] 5.3 Verificar que el indicador de progreso desaparece cuando la cotización pasa a `quoted` o `no_results` — el partial re-renderizado deriva el indicador de `quote.quoting?`
- [x] 5.4 Verificar que el refresco respeta el orden: una fila que llega tarde pero es más barata se ubica donde corresponde, no al final — se re-renderiza el bloque completo en lugar de anexar
- [x] 5.5 Test de sistema: con los resultados llegando de a uno, la pantalla los va incorporando sin intervención del usuario — cubierto a nivel job (broadcast emitido + reordenamiento), sin depender de Selenium

## 6. Validación end-to-end

- [x] 6.1 Test de sistema: cotizar contra los tres fakes y verificar tres filas con cuatro opciones cada una, ordenadas dentro y entre sí, con sus coberturas
- [x] 6.2 Test cubriendo una opción sin coberturas, construida a mano — resultó innecesario fabricarla: `Example Seguros` no devuelve `coverage`, así que el caso es real
- [x] 6.3 Verificar a mano el recorrido completo: apagar un proveedor desde el admin, cotizar, y confirmar que ese proveedor no aparece en los resultados
- [x] 6.4 Medir cuánto tarda la comparación completa con los tres fakes activos, como línea de base antes de sumar proveedores reales — 0,82 s promedio para los 4 fakes en serie e inline; es tiempo de base de datos, no de red, así que sirve como piso y no como predicción de proveedores reales
- [x] 6.5 Correr `bin/rails test` y `bin/rubocop` — 74 tests, 289 aserciones, 0 fallos; rubocop limpio

## 7. Toggle de activación de proveedores

- [x] 7.1 Agregar `member { patch :toggle_active }` a `resources :providers` en `config/routes.rb:10`
- [x] 7.2 Implementar `Admin::ProvidersController#toggle_active`, alternando entre `"active"` e `"inactive"` sobre el estado actual y escribiendo únicamente `status` (sin pasar por `provider_params`)
- [x] 7.3 Sumar el toggle a cada fila de `app/views/admin/providers/index.html.erb`, reutilizando las clases del `@layer components` y un icono Tabler
- [x] 7.4 Hacer visualmente evidente en el listado qué proveedores participarán de la próxima cotización — badge "Cotiza"/"No cotiza", fila atenuada y contador en la cabecera
- [x] 7.5 Test de controlador: el toggle activa, desactiva, y deja `config` intacto
- [x] 7.6 Test de controlador: un `producer` y un usuario sin sesión son rechazados y el `status` no cambia
- [x] 7.7 Probar a mano encendiendo y apagando Omint desde el admin, verificando que su `client_secret` sobrevive

## 8. Cierre

- [x] 8.1 Decidir si la vista pública recibe el mismo rediseño — la vista de resultados públicos no es `public/quotes/show.html.erb` (ese es el formulario) sino `public/landing/results.html.erb` + `_quote_status.html.erb`, con diseño de marca propio. No se reusan los partials del productor: se agrupó por proveedor con `offers_by_provider` conservando su diseño, porque la lista plana pasó de 4 a 13 tarjetas con los proveedores intercalados al sumar los tiers
- [x] 8.2 Decidir si la pantalla de cotización debe avisar cuando no hay ningún proveedor activo, o si se difiere a otro cambio — se avisa; el aviso reemplaza al indicador de "consultando" y no se muestra si ya hay resultados
- [x] 8.3 Decidir cuánto detalle de un proveedor fallido se le muestra al productor, evitando filtrar detalles internos de la integración — se muestra solo el nombre del proveedor; el mensaje crudo queda en `raw_response` para diagnóstico, fuera de la vista
- [x] 8.4 Dejar anotado que sumar proveedores reales exige revisar `threads` en `config/queue.yml` junto con el `+5` del pool en `config/database.yml:28` — subir uno sin el otro impide que Solid Queue arranque y tira Puma — documentado en CLAUDE.md, sección Background Jobs
- [x] 8.5 Confirmar que Omint sigue `inactive` al terminar y que este cambio no alteró su integración — `status=inactive`, `client_secret` y `agreement_number` intactos, sin diff en `omint_provider.rb`, su test ni `db/seeds.rb`
