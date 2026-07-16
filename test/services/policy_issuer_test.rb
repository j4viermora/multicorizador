require "test_helper"

class PolicyIssuerTest < ActiveSupport::TestCase
  setup do
    @quote_result = quote_results(:producer_quote_assist_card)
  end

  test "creates a policy and marks the quote as purchased" do
    policy = PolicyIssuer.call(
      quote_result: @quote_result,
      policy_number: "POL-0001",
      premium: Money.new(45000, "ARS"),
      sold_via: "direct"
    )

    assert policy.persisted?
    assert_equal "direct", policy.sold_via
    assert_equal "purchased", @quote_result.quote.reload.status
  end

  test "calling twice with the same policy_number does not create a duplicate" do
    first = PolicyIssuer.call(
      quote_result: @quote_result,
      policy_number: "POL-0002",
      premium: Money.new(45000, "ARS"),
      sold_via: "producer"
    )

    assert_no_difference "Policy.count" do
      second = PolicyIssuer.call(
        quote_result: @quote_result,
        policy_number: "POL-0002",
        premium: Money.new(45000, "ARS"),
        sold_via: "producer"
      )

      assert_equal first.id, second.id
    end
  end
end
