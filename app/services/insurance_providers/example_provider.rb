module InsuranceProviders
  class ExampleProvider < BaseProvider
    def self.slug = "example_seguros"

    def quote(quote)
      sleep(0.5) # Simula latencia de red
      {
        external_quote_id: "EXT-#{SecureRandom.hex(8).upcase}",
        price_cents: rand(5000..50000),
        currency: Money.default_currency.iso_code,
        plan_name: "Plan #{['Básico', 'Estándar', 'Premium'].sample}",
        valid_until: 24.hours.from_now
      }
    end

    def purchase_url(quote_result)
      "#{provider.config_for(:checkout_url)}?quote=#{quote_result.external_quote_id}"
    end

    def parse_webhook(payload)
      {
        policy_number: payload["policy_number"],
        issued_at: Time.parse(payload["issued_at"]),
        starts_at: Date.parse(payload["starts_at"]),
        ends_at: Date.parse(payload["ends_at"]),
        premium_cents: payload["premium_cents"],
        total_cents: payload["total_cents"]
      }
    end

    def valid_webhook?(request)
      token = request.headers["X-Provider-Token"]
      return false unless token
      ActiveSupport::SecurityUtils.secure_compare(token, provider.config_for(:webhook_token).to_s)
    end
  end
end
