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
        result = client.quote(quote)
        price = Money.new(result[:price_cents], result[:currency] || Money.default_currency)

        QuoteResult.create!(
          quote: quote,
          provider: provider,
          external_quote_id: result[:external_quote_id],
          raw_response: result,
          status: "success",
          price: price
        )
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

    ActsAsTenant.with_tenant(quote.company) { check_all_results_complete(quote) }
  end

  private

  def check_all_results_complete(quote)
    pending_count = quote.quote_results.where(status: "pending").count
    return if pending_count > 0

    quote.update!(status: "quoted")
  end
end
