require "test_helper"

class Producer::QuotesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:producer_uno) }

  test "new renders the whole quote form on a single screen" do
    get new_producer_quote_path

    assert_response :success
    assert_select "form[data-action=?]", "submit->quote-form#validate"
    assert_select ".qbar-field", minimum: 4
    assert_select "[data-quote-form-target=ages] [data-age-field]", 6
    assert_select "[data-quote-form-target=count][value=?]", "6"
    assert_select ".wizard-stepper", 0, "el stepper de dos pasos ya no existe"
  end

  test "show agrupa los resultados en una fila por proveedor" do
    quote = create_quote
    create_result(quote, providers(:assist_card), price_cents: 9_000, plan_name: "AC 500")
    create_result(quote, providers(:assist_card), price_cents: 5_000, plan_name: "AC 150")
    create_result(quote, providers(:travel_ace), price_cents: 3_000, plan_name: "TA Essential")

    get producer_quote_path(quote)

    assert_response :success
    assert_select ".offer-row", 2, "una fila por proveedor"
    assert_select ".offer-card", 3

    # Travel Ace cotiza más barato (3.000 vs 5.000), así que su fila va primera.
    provider_names = css_select("section h3").map(&:text).map(&:strip)
    assert_equal [ "Travel Ace", "Assist Card" ], provider_names

    # Y dentro de Assist Card, la opción barata precede a la cara.
    assist_card_plans = css_select("section:last-of-type .offer-card h4").map(&:text).map(&:strip)
    assert_equal [ "AC 150", "AC 500" ], assist_card_plans
  end

  test "show muestra las coberturas de cada opción" do
    quote = create_quote
    create_result(quote, providers(:assist_card), price_cents: 5_000, coverage: [
      { "name" => "Asistencia médica", "amount" => "USD 150.000" },
      { "name" => "Equipaje", "amount" => "USD 2.000" }
    ])

    get producer_quote_path(quote)

    assert_response :success
    assert_select ".offer-coverage", 2
    assert_select ".offer-coverage-name", text: "Asistencia médica"
    assert_select ".offer-coverage-amount", text: /USD 150\.000/
  end

  test "show tolera una opción sin coberturas" do
    quote = create_quote
    create_result(quote, providers(:assist_card), price_cents: 5_000, coverage: nil)

    get producer_quote_path(quote)

    assert_response :success
    assert_select ".offer-card", 1
    assert_select ".offer-coverage", 0
  end

  test "show tolera coberturas malformadas sin romper la pantalla" do
    quote = create_quote
    create_result(quote, providers(:assist_card), price_cents: 5_000, coverage: [
      { "name" => "Sin monto" },
      { "amount" => "USD 100" },
      "no soy un hash"
    ])

    get producer_quote_path(quote)

    assert_response :success
    assert_select ".offer-coverage", 1, "solo la cobertura con nombre se renderiza"
  end

  test "show identifica a los proveedores que no pudieron cotizar" do
    quote = create_quote
    create_result(quote, providers(:assist_card), price_cents: 5_000)
    create_result(quote, providers(:travel_ace), status: "error")

    get producer_quote_path(quote)

    assert_response :success
    assert_select ".offer-row", 1
    assert_select ".alert-warning", text: /Travel Ace/
  end

  test "show avisa cuando ningún proveedor pudo cotizar" do
    quote = create_quote
    create_result(quote, providers(:assist_card), status: "error")
    create_result(quote, providers(:travel_ace), status: "error")

    get producer_quote_path(quote)

    assert_response :success
    assert_select ".alert-error", text: /Ningún proveedor pudo cotizar/
  end

  test "show muestra los resultados parciales mientras sigue cotizando" do
    quote = create_quote(status: "quoting")
    create_result(quote, providers(:assist_card), price_cents: 5_000)

    get producer_quote_path(quote)

    assert_response :success
    assert_select ".loading", 1, "el indicador de progreso sigue visible"
    assert_select ".offer-card", 1, "los resultados que ya llegaron se muestran igual"
  end

  test "show avisa cuando no hay ningún proveedor activo" do
    Provider.update_all(status: "inactive")
    quote = create_quote(status: "quoting")

    get producer_quote_path(quote)

    assert_response :success
    assert_select ".alert-warning", text: /No hay proveedores activos/
    assert_select ".loading", 0, "no tiene sentido decir que está consultando si no hay a quién"
  end

  test "el aviso de sin proveedores no tapa los resultados que sí llegaron" do
    quote = create_quote
    create_result(quote, providers(:assist_card), price_cents: 5_000)
    Provider.update_all(status: "inactive")

    get producer_quote_path(quote)

    assert_response :success
    assert_select ".offer-card", 1
    assert_select ".alert-warning", 0
  end

  private

  def create_quote(status: "quoted")
    Quote.create!(
      company: companies(:ruka),
      producer: users(:producer_uno),
      status: status,
      origin: "EZE",
      destination: "MIA",
      departure_date: 30.days.from_now.to_date,
      return_date: 40.days.from_now.to_date,
      travelers_count: 1,
      metadata: { "ages" => [ 35 ] }
    )
  end

  def create_result(quote, provider, price_cents: 0, status: "success", plan_name: "Plan", coverage: [])
    QuoteResult.create!(
      company: companies(:ruka),
      quote: quote,
      provider: provider,
      status: status,
      price_cents: price_cents,
      raw_response: { "plan_name" => plan_name, "coverage" => coverage }.compact
    )
  end
end
