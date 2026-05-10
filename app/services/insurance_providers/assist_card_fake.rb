module InsuranceProviders
  class AssistCardFake < BaseProvider
    def self.slug = "assist_card_fake"

    BASE_DAILY_RATE = 480 # centavos USD por dia
    SENIOR_SURCHARGE = 1.65

    def quote(search)
      days = search.trip_days
      travelers = search.travelers_count
      age_factor = search.max_age >= 65 ? SENIOR_SURCHARGE : 1.0

      base = (BASE_DAILY_RATE * days * age_factor * travelers).round

      {
        external_quote_id: "AC-#{SecureRandom.hex(6).upcase}",
        price_cents: base,
        price_per_person_cents: (base / travelers.to_f).round,
        currency: "USD",
        plan_name: "Assist Card AC 150",
        provider_name: "Assist Card",
        valid_until: 24.hours.from_now,
        coverage: [
          { name: "Asistencia médica", amount: "USD 150.000" },
          { name: "Equipaje", amount: "USD 2.000" },
          { name: "Cancelación de viaje", amount: "USD 5.000" },
          { name: "Cobertura COVID-19", amount: "Incluida" },
          { name: "Repatriación sanitaria", amount: "USD 100.000" },
          { name: "Asistencia odontológica", amount: "USD 500" },
          { name: "Condiciones preexistentes", amount: "USD 30.000" },
          { name: "Demora de equipaje (+6hs)", amount: "USD 400" }
        ]
      }
    end

    def purchase_url(quote_result)
      "#"
    end
  end
end
