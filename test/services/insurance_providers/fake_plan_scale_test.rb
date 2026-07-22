require "test_helper"

module InsuranceProviders
  # Los tres fakes comparten FakePlanScale, así que las garantías de la escala se
  # verifican una vez contra cada uno en lugar de repetir el archivo por proveedor.
  class FakePlanScaleTest < ActiveSupport::TestCase
    FAKES = [ AssistCardFake, UniversalAssistanceFake, TravelAceFake ].freeze

    setup do
      @quote = quotes(:producer_quote)
    end

    FAKES.each do |fake_class|
      test "#{fake_class.slug} devuelve cuatro opciones de precios distintos y ordenables" do
        options = client_for(fake_class).quote(@quote)

        assert_equal 4, options.size
        prices = options.map { |o| o[:price_cents] }
        assert_equal prices.uniq.size, prices.size, "los precios deben ser distintos entre sí"
        assert_equal prices.sort, prices, "la escala debe venir de menor a mayor precio"
      end

      test "#{fake_class.slug} identifica cada opción de forma independiente" do
        options = client_for(fake_class).quote(@quote)

        ids = options.map { |o| o[:external_quote_id] }
        names = options.map { |o| o[:plan_name] }

        assert_equal ids.uniq.size, ids.size, "cada opción necesita su propio external_quote_id"
        assert_equal names.uniq.size, names.size, "cada opción necesita su propio plan_name"
      end

      test "#{fake_class.slug} escala las coberturas junto con el precio" do
        options = client_for(fake_class).quote(@quote)
        cheapest, priciest = options.first, options.last

        assert_operator priciest[:coverage].size, :>=, cheapest[:coverage].size

        cheapest_medical = amount_for(cheapest, "Asistencia médica")
        priciest_medical = amount_for(priciest, "Asistencia médica")

        assert_operator priciest_medical, :>, cheapest_medical,
          "la opción más cara debe cubrir más que la más económica"
      end

      test "#{fake_class.slug} aplica la duración del viaje a las cuatro opciones" do
        short = quote_with(departure: 30.days.from_now, return_date: 35.days.from_now)
        long = quote_with(departure: 30.days.from_now, return_date: 50.days.from_now)

        short_prices = client_for(fake_class).quote(short).map { |o| o[:price_cents] }
        long_prices = client_for(fake_class).quote(long).map { |o| o[:price_cents] }

        short_prices.zip(long_prices).each_with_index do |(short_price, long_price), index|
          assert_operator long_price, :>, short_price,
            "la opción #{index + 1} de un viaje más largo debe costar más"
        end
      end

      test "#{fake_class.slug} aplica el recargo por edad a las cuatro opciones" do
        young = quote_with(ages: [ 35 ])
        senior = quote_with(ages: [ 70 ])

        young_prices = client_for(fake_class).quote(young).map { |o| o[:price_cents] }
        senior_prices = client_for(fake_class).quote(senior).map { |o| o[:price_cents] }

        young_prices.zip(senior_prices).each_with_index do |(young_price, senior_price), index|
          assert_operator senior_price, :>, young_price,
            "la opción #{index + 1} debe aplicar el recargo por edad"
        end
      end

      test "#{fake_class.slug} aplica la cantidad de viajeros a las cuatro opciones" do
        single = quote_with(travelers: 1)
        couple = quote_with(travelers: 2)

        single_prices = client_for(fake_class).quote(single).map { |o| o[:price_cents] }
        couple_prices = client_for(fake_class).quote(couple).map { |o| o[:price_cents] }

        single_prices.zip(couple_prices).each do |single_price, couple_price|
          assert_equal single_price * 2, couple_price
        end
      end

      test "#{fake_class.slug} entrega el precio por persona coherente con el total" do
        options = client_for(fake_class).quote(quote_with(travelers: 2))

        options.each do |option|
          assert_equal (option[:price_cents] / 2.0).round, option[:price_per_person_cents]
        end
      end
    end

    test "una cobertura no incluida en el nivel base se informa en lugar de omitirse" do
      options = client_for(TravelAceFake).quote(@quote)
      covid = options.first[:coverage].find { |c| c[:name] == "Cobertura COVID-19" }

      assert_equal "No incluida", covid[:amount],
        "que un plan barato no cubra algo es información que el productor necesita"
    end

    private

    def client_for(fake_class)
      fake_class.new(Provider.new(slug: fake_class.slug, name: fake_class::PROVIDER_NAME))
    end

    def amount_for(option, coverage_name)
      raw = option[:coverage].find { |c| c[:name] == coverage_name }[:amount]
      raw.delete("^0-9").to_i
    end

    def quote_with(ages: [ 35 ], travelers: 1, departure: 30.days.from_now, return_date: 40.days.from_now)
      Quote.new(
        company: companies(:ruka),
        origin: "EZE",
        destination: "MIA",
        departure_date: departure.to_date,
        return_date: return_date.to_date,
        travelers_count: travelers,
        metadata: { "ages" => ages }
      )
    end
  end
end
