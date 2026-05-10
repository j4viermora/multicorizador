module InsuranceProviders
  class UniversalAssistanceFake < BaseProvider
    def self.slug = "universal_assistance_fake"

    BASE_DAILY_RATE = 350 # centavos USD por dia
    SENIOR_SURCHARGE = 1.55

    def quote(search)
      days = search.trip_days
      travelers = search.travelers_count
      age_factor = search.max_age >= 65 ? SENIOR_SURCHARGE : 1.0

      base = (BASE_DAILY_RATE * days * age_factor * travelers).round

      {
        external_quote_id: "UA-#{SecureRandom.hex(6).upcase}",
        price_cents: base,
        price_per_person_cents: (base / travelers.to_f).round,
        currency: "USD",
        plan_name: "UA Global Plus",
        provider_name: "Universal Assistance",
        valid_until: 24.hours.from_now,
        coverage: [
          { name: "Asistencia médica", amount: "USD 100.000" },
          { name: "Equipaje", amount: "USD 1.500" },
          { name: "Cancelación de viaje", amount: "USD 3.000" },
          { name: "Cobertura COVID-19", amount: "Incluida" },
          { name: "Repatriación sanitaria", amount: "USD 60.000" },
          { name: "Asistencia odontológica", amount: "USD 300" },
          { name: "Demora de equipaje (+6hs)", amount: "USD 200" }
        ]
      }
    end

    def purchase_url(quote_result)
      "#"
    end
  end
end
