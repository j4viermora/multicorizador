class QuoteJob < ApplicationJob
  queue_as :default

  def perform(quote_id)
    quote = ActsAsTenant.without_tenant { Quote.find(quote_id) }
    return unless quote.draft? || quote.client_pending?

    ActsAsTenant.with_tenant(quote.company) do
      providers = Provider.active.to_a

      # Sin proveedores activos no se encola nada, así que nadie llegaría a
      # cerrar la cotización y quedaría en `quoting` para siempre.
      if providers.empty?
        quote.update!(status: "no_results", expected_providers_count: 0)
        next
      end

      quote.update!(status: "quoting", expected_providers_count: providers.size)

      providers.each { |provider| ProviderQuoteJob.perform_later(quote.id, provider.id) }
    end
  end
end
