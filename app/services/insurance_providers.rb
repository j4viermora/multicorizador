module InsuranceProviders
  REGISTRY = {}

  def self.register(provider_class)
    REGISTRY[provider_class.slug] = provider_class
  end

  def self.for(provider)
    klass = REGISTRY[provider.slug]
    klass&.new(provider)
  end

  def self.available_slugs
    REGISTRY.keys
  end
end
