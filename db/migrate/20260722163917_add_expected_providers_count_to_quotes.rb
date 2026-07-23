class AddExpectedProvidersCountToQuotes < ActiveRecord::Migration[8.0]
  # Cuántos proveedores se encolaron para esta cotización. Sin este dato no hay
  # forma de saber si el fan-out terminó: ProviderQuoteJob solo crea resultados
  # `success` o `error`, así que contar los `pending` daba siempre cero y el
  # primer proveedor en responder marcaba la cotización como `quoted`.
  #
  # Se fija al encolar en lugar de leer Provider.active en cada chequeo, porque
  # activar o desactivar un proveedor mientras se cotiza movería el objetivo.
  #
  # Nullable a propósito: las cotizaciones anteriores a esta migración no lo
  # tienen y conservan el comportamiento viejo en lugar de quedarse colgadas.
  def change
    add_column :quotes, :expected_providers_count, :integer
  end
end
