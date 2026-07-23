module InsuranceProviders
  class AssistCardFake < BaseProvider
    include FakePlanScale

    def self.slug = "assist_card_fake"

    PROVIDER_NAME = "Assist Card".freeze
    QUOTE_ID_PREFIX = "AC".freeze

    BASE_DAILY_RATE = 480 # centavos USD por dia
    SENIOR_SURCHARGE = 1.65

    COVERAGES = [
      { name: "Asistencia médica", base_amount: 150_000 },
      { name: "Equipaje", base_amount: 2_000 },
      { name: "Cancelación de viaje", base_amount: 5_000 },
      { name: "Repatriación sanitaria", base_amount: 100_000 },
      { name: "Asistencia odontológica", base_amount: 500 },
      { name: "Demora de equipaje (+6hs)", base_amount: 400 },
      { name: "Condiciones preexistentes", base_amount: 30_000, from_tier: 2 },
      { name: "Cobertura COVID-19", covered_from: 1 },
      { name: "Deportes de riesgo", covered_from: 3 }
    ].freeze

    TIERS = [
      { level: 1, name: "Assist Card AC 150", price_factor: 1.0, coverage_factor: 1.0 },
      { level: 2, name: "Assist Card AC 250", price_factor: 1.32, coverage_factor: 1.65 },
      { level: 3, name: "Assist Card AC 500", price_factor: 1.78, coverage_factor: 3.3 },
      { level: 4, name: "Assist Card Platinum", price_factor: 2.4, coverage_factor: 6.6 }
    ].freeze
  end
end
