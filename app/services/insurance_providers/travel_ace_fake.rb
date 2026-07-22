module InsuranceProviders
  class TravelAceFake < BaseProvider
    include FakePlanScale

    def self.slug = "travel_ace_fake"

    PROVIDER_NAME = "Travel Ace".freeze
    QUOTE_ID_PREFIX = "TA".freeze

    BASE_DAILY_RATE = 220 # centavos USD por dia
    SENIOR_SURCHARGE = 1.45

    COVERAGES = [
      { name: "Asistencia médica", base_amount: 50_000 },
      { name: "Equipaje", base_amount: 800 },
      { name: "Cancelación de viaje", base_amount: 1_500 },
      { name: "Repatriación sanitaria", base_amount: 30_000 },
      { name: "Asistencia odontológica", base_amount: 150 },
      { name: "Condiciones preexistentes", base_amount: 10_000, from_tier: 3 },
      { name: "Cobertura COVID-19", covered_from: 2 },
      { name: "Demora de equipaje (+6hs)", covered_from: 2 }
    ].freeze

    TIERS = [
      { level: 1, name: "Travel Ace Essential", price_factor: 1.0, coverage_factor: 1.0 },
      { level: 2, name: "Travel Ace Classic", price_factor: 1.4, coverage_factor: 2.0 },
      { level: 3, name: "Travel Ace Premium", price_factor: 1.95, coverage_factor: 4.0 },
      { level: 4, name: "Travel Ace Elite", price_factor: 2.6, coverage_factor: 8.0 }
    ].freeze
  end
end
