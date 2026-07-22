class ProviderQuoteJob < ApplicationJob
  queue_as :default
  retry_on InsuranceProviders::BaseProvider::ProviderError, wait: 5.seconds, attempts: 3

  def perform(quote_id, provider_id)
    quote = ActsAsTenant.without_tenant { Quote.find(quote_id) }
    provider = Provider.find(provider_id)
    client = InsuranceProviders.for(provider)

    return unless client

    ActsAsTenant.with_tenant(quote.company) do
      begin
        results = Array.wrap(client.quote(quote))
        results.each do |result|
          price = Money.new(result[:price_cents], result[:currency] || Money.default_currency)

          QuoteResult.create!(
            quote: quote,
            provider: provider,
            external_quote_id: result[:external_quote_id],
            raw_response: result,
            status: "success",
            price: price
          )
        end
      rescue => e
        QuoteResult.create!(
          quote: quote,
          provider: provider,
          status: "error",
          raw_response: { error: e.message, backtrace: e.backtrace&.first(5) }
        )
        raise if Rails.env.development?
      end
    end

    ActsAsTenant.with_tenant(quote.company) do
      check_all_results_complete(quote)
      broadcast_results(quote)
    end
  end

  private

  # Re-renderiza el bloque de resultados completo en lugar de agregar la fila
  # nueva al final: las filas se ordenan por precio, así que un proveedor que
  # responde tarde pero cotiza más barato tiene que ubicarse arriba.
  #
  # Se emite en cada respuesta, y a las dos pantallas. La pública dependía de un
  # único mensaje —el de `Quote#broadcast_status_update`, que solo dispara al
  # cambiar el estado— así que una entrega perdida dejaba al cliente mirando el
  # spinner para siempre, sin nada que lo corrigiera. Con un mensaje por
  # proveedor, el siguiente repara lo que el anterior no haya alcanzado.
  def broadcast_results(quote)
    Turbo::StreamsChannel.broadcast_replace_to(
      quote, :results,
      target: ActionView::RecordIdentifier.dom_id(quote, :results),
      partial: "producer/quotes/results",
      locals: { quote: quote }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "quote_#{quote.id}",
      target: "quote_status_#{quote.id}",
      partial: "public/landing/quote_status",
      locals: { quote: quote }
    )
  end

  # La cotización se cierra recién cuando respondieron todos los proveedores que
  # se encolaron, no cuando responde el primero.
  #
  # Se cuentan proveedores distintos y no resultados, porque un proveedor puede
  # devolver varias opciones de plan. El lock evita que dos jobs que terminan a
  # la vez lean el conteo antes de que el otro haya commiteado y ninguno cierre.
  def check_all_results_complete(quote)
    quote.with_lock do
      expected = quote.expected_providers_count

      if expected.present?
        responded = quote.quote_results.distinct.count(:provider_id)
        next if responded < expected
      end

      quote.update!(status: quote.quote_results.successful.any? ? "quoted" : "no_results")
    end
  end
end
