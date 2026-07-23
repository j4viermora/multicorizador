require "test_helper"

class Public::LandingControllerTest < ActionDispatch::IntegrationTest
  setup { @company = companies(:ruka) }

  test "show renders the single-screen quote bar" do
    get public_landing_path(@company.slug)

    assert_response :success
    assert_select ".qbar-field", minimum: 6
    assert_select "[data-quote-form-target=ages] [data-age-field]", 6
    assert_select "input[name=?]", "quote[metadata][ages][]"
    assert_select ".wizard-stepper", 0, "el stepper de dos pasos ya no existe"
  end

  test "create takes trip, ages and contact data in one submission" do
    assert_difference "Quote.count", 1 do
      post public_landing_path(@company.slug), params: {
        quote: {
          origin: "Argentina",
          destination: "Europa",
          departure_date: Date.today.iso8601,
          return_date: 10.days.from_now.to_date.iso8601,
          trip_type: "single",
          travelers_count: 2,
          metadata: { ages: %w[34 8], email: "cliente@example.com", phone: "+5491112345678" }
        }
      }
    end

    quote = ActsAsTenant.with_tenant(@company) { Quote.order(:created_at).last }

    assert_redirected_to public_landing_results_path(@company.slug, quote.public_token)
    assert_equal 2, quote.travelers_count
    assert_equal %w[34 8], quote.metadata["ages"]
    assert_equal "cliente@example.com", quote.metadata["email"]
  end

  test "results agrupa los planes en una fila por proveedor" do
    quote = create_quoted_quote
    create_result(quote, providers(:assist_card), price_cents: 9_000, plan_name: "AC 500")
    create_result(quote, providers(:assist_card), price_cents: 5_000, plan_name: "AC 150")
    create_result(quote, providers(:travel_ace), price_cents: 3_000, plan_name: "TA Essential")

    get public_landing_results_path(@company.slug, quote.public_token)

    assert_response :success
    assert_select ".provider-row", 2, "un proveedor por fila, no una lista plana"
    assert_select ".result-card", 3

    # Travel Ace cotiza más barato, así que su fila va primera.
    provider_names = css_select(".provider-row .provider-badge").map(&:text).map(&:strip)
    assert_equal [ "Travel Ace", "Assist Card" ], provider_names

    # Y dentro de Assist Card, el plan barato precede al caro.
    plans = css_select(".provider-row:last-of-type .result-card h3").map(&:text).map(&:strip)
    assert_equal [ "AC 150", "AC 500" ], plans
  end

  test "results marca como destacado solo el plan más barato de todos" do
    quote = create_quoted_quote
    create_result(quote, providers(:assist_card), price_cents: 9_000)
    create_result(quote, providers(:travel_ace), price_cents: 3_000)
    create_result(quote, providers(:travel_ace), price_cents: 4_000)

    get public_landing_results_path(@company.slug, quote.public_token)

    assert_response :success
    assert_select ".result-card.is-best", 1
    assert_select ".result-cta-primary", 1, "un solo llamado a la acción principal"
  end

  test "results tolera un plan sin coberturas" do
    quote = create_quoted_quote
    create_result(quote, providers(:assist_card), price_cents: 5_000, coverage: nil)

    get public_landing_results_path(@company.slug, quote.public_token)

    assert_response :success
    assert_select ".result-card", 1
    assert_select ".coverage-item", 0
  end

  private

  def create_quoted_quote
    ActsAsTenant.with_tenant(@company) do
      Quote.create!(
        company: @company,
        producer: users(:producer_uno),
        status: "quoted",
        origin: "EZE",
        destination: "MIA",
        departure_date: 30.days.from_now.to_date,
        return_date: 40.days.from_now.to_date,
        travelers_count: 1,
        metadata: { "ages" => [ 35 ] }
      )
    end
  end

  def create_result(quote, provider, price_cents: 0, plan_name: "Plan", coverage: [])
    QuoteResult.create!(
      company: @company,
      quote: quote,
      provider: provider,
      status: "success",
      price_cents: price_cents,
      raw_response: {
        "plan_name" => plan_name,
        "currency" => "USD",
        "price_cents" => price_cents,
        "coverage" => coverage
      }.compact
    )
  end
end
