module InsuranceProviders
  # Escala de planes compartida por los proveedores fake.
  #
  # Cada fake declara su tarifa diaria (BASE_DAILY_RATE), su recargo por edad
  # (SENIOR_SURCHARGE), sus coberturas (COVERAGES) y sus niveles de plan (TIERS).
  # El cálculo del precio y la forma del hash de cotización viven acá para que
  # agregar un escalón sea una línea y no una tabla de precios nueva.
  #
  # El precio de cada nivel se deriva del cálculo base — días x viajeros x recargo
  # por edad — multiplicado por el `price_factor` del nivel. El nivel más bajo usa
  # factor 1.0, así que conserva el precio que el fake devolvía cuando cotizaba un
  # único plan.
  module FakePlanScale
    # Montos de cobertura que escalan con el nivel. Los que no son numéricos
    # (una cobertura que está incluida o no) se resuelven contra `covered_from`.
    def quote(search)
      base = base_price(search)

      self.class::TIERS.map do |tier|
        price = (base * tier[:price_factor]).round

        {
          external_quote_id: "#{self.class::QUOTE_ID_PREFIX}-#{SecureRandom.hex(6).upcase}",
          price_cents: price,
          price_per_person_cents: (price / search.travelers_count.to_f).round,
          currency: "USD",
          plan_name: tier[:name],
          provider_name: self.class::PROVIDER_NAME,
          valid_until: 24.hours.from_now,
          coverage: coverage_for(tier)
        }
      end
    end

    def purchase_url(quote_result)
      "#"
    end

    private

    def base_price(search)
      age_factor = search.max_age >= 65 ? self.class::SENIOR_SURCHARGE : 1.0

      (self.class::BASE_DAILY_RATE * search.trip_days * age_factor * search.travelers_count).round
    end

    def coverage_for(tier)
      self.class::COVERAGES.filter_map do |coverage|
        amount = coverage_amount(coverage, tier)
        next if amount.nil?

        { name: coverage[:name], amount: amount }
      end
    end

    # Una cobertura con `base_amount` escala su monto con el nivel. Una sin monto
    # se incluye recién a partir del nivel indicado en `covered_from`, y por debajo
    # de ese nivel se muestra como no incluida en lugar de desaparecer: que un plan
    # barato NO cubra algo es información que el productor necesita al comparar.
    def coverage_amount(coverage, tier)
      if coverage[:base_amount]
        return nil if coverage[:from_tier] && tier[:level] < coverage[:from_tier]

        format_usd((coverage[:base_amount] * tier[:coverage_factor]).round)
      else
        tier[:level] >= coverage[:covered_from] ? "Incluida" : "No incluida"
      end
    end

    def format_usd(amount)
      "USD #{ActiveSupport::NumberHelper.number_to_delimited(amount, delimiter: '.')}"
    end
  end
end
