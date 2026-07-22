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
end
