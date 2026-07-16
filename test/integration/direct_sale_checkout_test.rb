require "test_helper"

class DirectSaleCheckoutTest < ActionDispatch::IntegrationTest
  setup do
    @company = companies(:ruka)
    @quote = quotes(:producer_quote)
    @quote.update!(created_by: "client", status: "quoted")
    @quote_result = quote_results(:producer_quote_assist_card)
  end

  test "completing checkout on the public landing issues a real policy with the direct channel" do
    assert_difference "Policy.count", 1 do
      post public_landing_checkout_path(@company.slug), params: {
        quote_token: @quote.public_token,
        plan: { quote_result_id: @quote_result.id, provider_name: "Assist Card", price_cents: 45_000 },
        search: { origin: @quote.origin, destination: @quote.destination, travelers_count: 1 },
        passengers: [ { first_name: "Juan", last_name: "Perez", document: "30111222", birth_date: "1990-05-10" } ],
        contact: { email: "juan@example.com", phone: "+5491100000000" },
        emergency: { name: "Maria Perez", phone: "+5491100000001" }
      }
    end

    assert_response :success

    policy = Policy.last
    assert_equal "direct", policy.sold_via
    assert_equal @quote_result.id, policy.quote_result_id

    @quote.reload
    assert_equal "purchased", @quote.status
    assert @quote.traveler.present?
    assert_equal "Juan", @quote.traveler.first_name
  end
end
