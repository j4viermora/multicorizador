class QuoteJob < ApplicationJob
  queue_as :default

  def perform(quote_id)
    quote = Quote.find(quote_id)
    return unless quote.draft? || quote.client_pending?

    quote.update!(status: "quoting")

    Provider.active.find_each do |provider|
      ProviderQuoteJob.perform_later(quote.id, provider.id)
    end
  end
end
