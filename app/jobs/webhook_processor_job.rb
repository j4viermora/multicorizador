class WebhookProcessorJob < ApplicationJob
  queue_as :default

  def perform(provider_slug, payload)
    provider = Provider.find_by!(slug: provider_slug)
    client = InsuranceProviders.for(provider)

    return unless client

    parsed = client.parse_webhook(payload)
    quote_result = QuoteResult.find_by(external_quote_id: parsed[:external_quote_id])

    return unless quote_result

    PolicyIssuer.call(
      quote_result: quote_result,
      policy_number: parsed[:policy_number],
      issued_at: parsed[:issued_at],
      starts_at: parsed[:starts_at],
      ends_at: parsed[:ends_at],
      premium: quote_result.price,
      total: parsed[:total_cents] ? Money.new(parsed[:total_cents]) : quote_result.price,
      sold_via: "producer",
      webhook_payload: payload
    )
  end
end
