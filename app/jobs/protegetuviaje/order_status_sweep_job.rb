module Protegetuviaje
  # Protegetuviaje no ofrece webhook (a diferencia de otros proveedores acá),
  # así que la única forma de saber si una orden ya se pagó es preguntarle
  # por su estado. Este job barre las cotizaciones en pending_payment con una
  # orden de Protegetuviaje pendiente y las resuelve: emite la póliza si ya
  # está paga, o libera la cotización si la orden se canceló.
  #
  # Corre por config/recurring.yml, no encolado por otro job — así que no
  # depende de que nada dispare la revisión.
  class OrderStatusSweepJob < ApplicationJob
    queue_as :default

    def perform
      ActsAsTenant.without_tenant do
        QuoteResult.joins(:quote, :provider)
                   .where(quotes: { status: "pending_payment" })
                   .where(providers: { slug: InsuranceProviders::ProtegetuviajeProvider.slug })
                   .find_each { |quote_result| check!(quote_result) }
      end
    end

    private

    def check!(quote_result)
      order_serial = quote_result.raw_response["order_serial"]
      return if order_serial.blank?

      client = InsuranceProviders.for(quote_result.provider)
      ActsAsTenant.with_tenant(quote_result.company) do
        status = client.order_status(order_serial)

        case status[:state]
        when :paid then issue_policy!(quote_result, status)
        when :cancelled then quote_result.quote.update!(status: "cancelled")
        end
      end
    rescue InsuranceProviders::BaseProvider::ProviderError => e
      Rails.logger.error("[Protegetuviaje::OrderStatusSweepJob] quote_result=#{quote_result.id} #{e.message}")
    end

    def issue_policy!(quote_result, status)
      quote = quote_result.quote
      total = status[:total].to_f
      total_money = Money.new((total * 100).round, status[:currency] || quote_result.price_currency)

      PolicyIssuer.call(
        quote_result: quote_result,
        policy_number: quote_result.raw_response["order_code"] || "PTV-#{quote_result.id}",
        issued_at: Time.current,
        starts_at: quote.departure_date,
        ends_at: quote.return_date,
        premium: total_money,
        total: total_money,
        sold_via: "direct",
        webhook_payload: status[:raw]
      )
    end
  end
end
