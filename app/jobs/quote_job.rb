class QuoteJob < ApplicationJob
  queue_as :default

  def perform(quote_id)
    quote = ActsAsTenant.without_tenant { Quote.find(quote_id) }
    return unless quote.draft? || quote.client_pending?

    ActsAsTenant.with_tenant(quote.company) do
      quote.update!(status: "quoting")

      Provider.active.find_each do |provider|
        ProviderQuoteJob.perform_later(quote.id, provider.id)
      end
    end
  end
end
