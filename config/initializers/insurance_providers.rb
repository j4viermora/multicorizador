Rails.application.config.to_prepare do
  InsuranceProviders.register(InsuranceProviders::ExampleProvider)
  InsuranceProviders.register(InsuranceProviders::AssistCardFake)
  InsuranceProviders.register(InsuranceProviders::UniversalAssistanceFake)
  InsuranceProviders.register(InsuranceProviders::TravelAceFake)
end
