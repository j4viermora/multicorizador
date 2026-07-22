module InsuranceProviders
  class UniversalAssistanceFake < BaseProvider
    include FakePlanScale

    def self.slug = "universal_assistance_fake"

    PROVIDER_NAME = "Universal Assistance".freeze
    QUOTE_ID_PREFIX = "UA".freeze

    BASE_DAILY_RATE = 350 # centavos USD por dia
    SENIOR_SURCHARGE = 1.55

    COVERAGES = [
      { name: "Asistencia médica", base_amount: 100_000 },
      { name: "Equipaje", base_amount: 1_500 },
      { name: "Cancelación de viaje", base_amount: 3_000 },
      { name: "Repatriación sanitaria", base_amount: 60_000 },
      { name: "Asistencia odontológica", base_amount: 300 },
      { name: "Demora de equipaje (+6hs)", base_amount: 200 },
      { name: "Condiciones preexistentes", base_amount: 20_000, from_tier: 3 },
      { name: "Cobertura COVID-19", covered_from: 1 },
      { name: "Asistencia legal", covered_from: 2 }
    ].freeze

    TIERS = [
      { level: 1, name: "UA Global Plus", price_factor: 1.0, coverage_factor: 1.0 },
      { level: 2, name: "UA Global Total", price_factor: 1.28, coverage_factor: 1.8 },
      { level: 3, name: "UA Premium", price_factor: 1.7, coverage_factor: 3.0 },
      { level: 4, name: "UA Premium Max", price_factor: 2.15, coverage_factor: 5.0 }
    ].freeze
  end
end
