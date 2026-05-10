Rails.application.config.after_initialize do
  InsuranceProviders.register(InsuranceProviders::ExampleProvider)
end
