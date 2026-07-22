require "test_helper"

class QuoteTest < ActiveSupport::TestCase
  setup do
    @company = companies(:ruka)
    ActsAsTenant.current_tenant = @company

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

    @assist_card = providers(:assist_card)
    @travel_ace = providers(:travel_ace)
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "agrupa los resultados exitosos en una fila por proveedor" do
    2.times { |i| create_result(@assist_card, price_cents: 5_000 + i) }
    3.times { |i| create_result(@travel_ace, price_cents: 3_000 + i) }

    offers = @quote.offers_by_provider

    assert_equal 2, offers.size
    assert_equal [ @travel_ace, @assist_card ], offers.map(&:provider)
    assert_equal [ 3, 2 ], offers.map { |o| o.options.size }
  end

  test "ordena las opciones de cada proveedor de menor a mayor precio" do
    create_result(@assist_card, price_cents: 9_000)
    create_result(@assist_card, price_cents: 4_000)
    create_result(@assist_card, price_cents: 6_000)

    options = @quote.offers_by_provider.first.options

    assert_equal [ 4_000, 6_000, 9_000 ], options.map(&:price_cents)
  end

  test "ordena las filas por la opción más económica de cada proveedor" do
    create_result(@assist_card, price_cents: 2_000)
    create_result(@assist_card, price_cents: 20_000)
    create_result(@travel_ace, price_cents: 5_000)
    create_result(@travel_ace, price_cents: 6_000)

    offers = @quote.offers_by_provider

    assert_equal [ @assist_card, @travel_ace ], offers.map(&:provider),
      "manda el precio mínimo de cada proveedor, no el máximo ni el promedio"
    assert_equal [ 2_000, 5_000 ], offers.map(&:cheapest_price_cents)
  end

  test "dos opciones del mismo precio se conservan ambas" do
    create_result(@assist_card, price_cents: 5_000)
    create_result(@assist_card, price_cents: 5_000)

    assert_equal 2, @quote.offers_by_provider.first.options.size
  end

  test "un proveedor con un único resultado forma su propia fila" do
    create_result(@assist_card, price_cents: 5_000)

    offers = @quote.offers_by_provider

    assert_equal 1, offers.size
    assert_equal 1, offers.first.options.size
  end

  test "expone los proveedores fallidos en lugar de descartarlos" do
    create_result(@assist_card, price_cents: 5_000)
    create_result(@travel_ace, status: "error")

    assert_equal [ @assist_card ], @quote.offers_by_provider.map(&:provider)
    assert_equal [ @travel_ace ], @quote.failed_providers
  end

  test "no repite un proveedor que falló más de una vez" do
    2.times { create_result(@travel_ace, status: "error") }

    assert_equal [ @travel_ace ], @quote.failed_providers
  end

  test "sin resultados exitosos las filas quedan vacías" do
    create_result(@assist_card, status: "error")

    assert_empty @quote.offers_by_provider
    assert_equal [ @assist_card ], @quote.failed_providers
  end

  private

  def create_result(provider, price_cents: 0, status: "success")
    QuoteResult.create!(
      company: @company,
      quote: @quote,
      provider: provider,
      status: status,
      price_cents: price_cents,
      raw_response: {}
    )
  end
end
