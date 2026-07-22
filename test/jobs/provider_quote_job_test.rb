require "test_helper"
require "turbo/broadcastable/test_helper"

class ProviderQuoteJobTest < ActiveJob::TestCase
  # turbo-rails no lo carga por su cuenta en ActiveJob::TestCase: sin el require
  # y el include, el test pasa cuando el archivo corre solo y falla en la suite.
  include Turbo::Broadcastable::TestHelper
  # Proveedores de prueba registrados en el REGISTRY real en lugar de stubear
  # InsuranceProviders.for: el registro por slug es el mecanismo que el job usa
  # en producción, así que ejercitarlo también cubre esa resolución.
  class MultiOptionProvider < InsuranceProviders::BaseProvider
    def self.slug = "test_multi_option"

    def quote(_search)
      3.times.map do |i|
        {
          external_quote_id: "MULTI-#{i}",
          price_cents: 1_000 * (i + 1),
          currency: "USD",
          plan_name: "Plan #{i + 1}"
        }
      end
    end
  end

  class SingleOptionProvider < InsuranceProviders::BaseProvider
    def self.slug = "test_single_option"

    def quote(_search)
      { external_quote_id: "SINGLE-1", price_cents: 1_000, currency: "USD", plan_name: "Plan único" }
    end
  end

  class ExpensiveProvider < InsuranceProviders::BaseProvider
    def self.slug = "test_expensive"

    def quote(_search)
      [ { external_quote_id: "EXP-1", price_cents: 90_000, currency: "USD", plan_name: "Plan caro" } ]
    end
  end

  class FailingProvider < InsuranceProviders::BaseProvider
    def self.slug = "test_failing"

    def quote(_search)
      raise InsuranceProviders::BaseProvider::ProviderError, "API caída"
    end
  end

  TEST_PROVIDERS = [ MultiOptionProvider, SingleOptionProvider, ExpensiveProvider, FailingProvider ].freeze

  setup do
    @company = companies(:ruka)
    ActsAsTenant.current_tenant = @company

    # Cotización propia: las fixtures ya traen resultados asociados a las suyas.
    @quote = Quote.create!(
      company: @company,
      producer: users(:producer_uno),
      origin: "EZE",
      destination: "MIA",
      departure_date: 30.days.from_now.to_date,
      return_date: 40.days.from_now.to_date,
      travelers_count: 1,
      metadata: { "ages" => [ 35 ] }
    )

    TEST_PROVIDERS.each { |klass| InsuranceProviders.register(klass) }
  end

  teardown do
    TEST_PROVIDERS.each { |klass| InsuranceProviders::REGISTRY.delete(klass.slug) }
    ActsAsTenant.current_tenant = nil
  end

  test "un proveedor que devuelve varias opciones produce un resultado por opción" do
    provider = create_provider(MultiOptionProvider)

    ProviderQuoteJob.perform_now(@quote.id, provider.id)

    results = @quote.quote_results.where(provider: provider)

    assert_equal 3, results.count
    assert results.all? { |r| r.status == "success" }
    assert_equal [ provider.id ], results.map(&:provider_id).uniq
    assert_equal 3, results.map(&:external_quote_id).uniq.size
  end

  test "un proveedor que devuelve un hash único produce un solo resultado" do
    provider = create_provider(SingleOptionProvider)

    ProviderQuoteJob.perform_now(@quote.id, provider.id)

    results = @quote.quote_results.where(provider: provider)

    assert_equal 1, results.count
    assert_equal "SINGLE-1", results.first.external_quote_id
  end

  test "un proveedor que falla produce un único resultado en error" do
    provider = create_provider(FailingProvider)

    ProviderQuoteJob.perform_now(@quote.id, provider.id)

    results = @quote.quote_results.where(provider: provider)

    assert_equal 1, results.count
    assert_equal "error", results.first.status
    assert_equal "API caída", results.first.raw_response["error"]
  end

  test "el fallo de un proveedor no afecta las opciones ya creadas por otro" do
    healthy = create_provider(MultiOptionProvider)
    broken = create_provider(FailingProvider)

    ProviderQuoteJob.perform_now(@quote.id, healthy.id)
    ProviderQuoteJob.perform_now(@quote.id, broken.id)

    assert_equal 3, @quote.quote_results.where(provider: healthy, status: "success").count
    assert_equal 1, @quote.quote_results.where(provider: broken, status: "error").count
  end

  test "emite los resultados por Turbo Stream al terminar cada proveedor" do
    provider = create_provider(MultiOptionProvider)

    assert_turbo_stream_broadcasts([ @quote, :results ], count: 1) do
      ProviderQuoteJob.perform_now(@quote.id, provider.id)
    end
  end

  test "el refresco reordena las filas cuando un proveedor barato responde tarde" do
    expensive = create_provider(ExpensiveProvider)   # una opción de 90.000
    cheap = create_provider(MultiOptionProvider)     # opciones desde 1.000

    ProviderQuoteJob.perform_now(@quote.id, expensive.id)
    ProviderQuoteJob.perform_now(@quote.id, cheap.id)

    # El bloque se re-renderiza entero, así que el proveedor que llegó último
    # queda donde le corresponde por precio y no al final.
    offers = @quote.reload.offers_by_provider
    assert_equal cheap, offers.first.provider
    assert_operator offers.first.cheapest_price_cents, :<, offers.last.cheapest_price_cents
  end

  test "los fakes del proyecto producen cuatro resultados por proveedor" do
    provider = providers(:assist_card)
    before = @quote.quote_results.where(provider: provider).count

    ProviderQuoteJob.perform_now(@quote.id, provider.id)

    assert_equal before + 4, @quote.quote_results.where(provider: provider).count
  end

  private

  def create_provider(klass)
    Provider.create!(name: klass.name.demodulize, slug: klass.slug, status: "active", config: {})
  end
end
