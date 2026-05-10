module InsuranceProviders
  class TravelAceFake < BaseProvider
    def self.slug = "travel_ace_fake"

    BASE_DAILY_RATE = 220 # centavos USD por dia
    SENIOR_SURCHARGE = 1.45

    def quote(search)
      days = search.trip_days
      travelers = search.travelers_count
      age_factor = search.max_age >= 65 ? SENIOR_SURCHARGE : 1.0

      base = (BASE_DAILY_RATE * days * age_factor * travelers).round

      {
        external_quote_id: "TA-#{SecureRandom.hex(6).upcase}",
        price_cents: base,
        price_per_person_cents: (base / travelers.to_f).round,
        currency: "USD",
        plan_name: "Travel Ace Essential",
        provider_name: "Travel Ace",
        valid_until: 24.hours.from_now,
        coverage: [
          { name: "Asistencia médica", amount: "USD 50.000" },
          { name: "Equipaje", amount: "USD 800" },
          { name: "Cancelación de viaje", amount: "USD 1.500" },
          { name: "Cobertura COVID-19", amount: "No incluida" },
          { name: "Repatriación sanitaria", amount: "USD 30.000" },
          { name: "Asistencia odontológica", amount: "USD 150" }
        ]
      }
    end

    def purchase_url(quote_result)
      "#"
    end
  end
end
