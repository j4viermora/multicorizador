class ProviderQuoteJob < ApplicationJob
  queue_as :default
  retry_on InsuranceProviders::BaseProvider::ProviderError, wait: 5.seconds, attempts: 3

  def perform(quote_id, provider_id)
    quote = Quote.find(quote_id)
    provider = Provider.find(provider_id)
    client = InsuranceProviders.for(provider)

    return unless client

    begin
      result = client.quote(quote)
      contract = CommissionContract.resolve(provider, quote.producer)

      price = Money.new(result[:price_cents], result[:currency] || Money.default_currency)
      provider_commission = price * contract.provider_commission_rate
      producer_commission = provider_commission * contract.producer_share_rate
      platform_commission = provider_commission - producer_commission

      QuoteResult.create!(
        quote: quote,
        provider: provider,
        external_quote_id: result[:external_quote_id],
        raw_response: result,
        status: "success",
        price: price,
        provider_commission: provider_commission,
        platform_commission: platform_commission,
        producer_commission: producer_commission
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

    check_all_results_complete(quote)
  end

  private

  def check_all_results_complete(quote)
    pending_count = quote.quote_results.where(status: "pending").count
    return if pending_count > 0

    quote.update!(status: "quoted")
  end
end
