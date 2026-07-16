require "test_helper"

class WebhookProcessorJobTest < ActiveSupport::TestCase
  setup do
    @quote_result = quote_results(:producer_quote_assist_card)
    @provider = @quote_result.provider

    @payload = {
      "policy_number" => "POL-WEBHOOK-1",
      "issued_at" => Time.current.iso8601,
      "starts_at" => 10.days.from_now.to_date.iso8601,
      "ends_at" => 20.days.from_now.to_date.iso8601,
      "premium_cents" => 45_000,
      "total_cents" => 45_000
    }

    @fake_client = Object.new
    quote_result_external_id = @quote_result.external_quote_id
    @fake_client.define_singleton_method(:parse_webhook) do |payload|
      {
        external_quote_id: quote_result_external_id,
        policy_number: payload["policy_number"],
        issued_at: Time.parse(payload["issued_at"]),
        starts_at: Date.parse(payload["starts_at"]),
        ends_at: Date.parse(payload["ends_at"]),
        premium_cents: payload["premium_cents"],
        total_cents: payload["total_cents"]
      }
    end
  end

  test "a valid webhook creates a policy attributed to the producer channel" do
    with_stubbed_client do
      WebhookProcessorJob.perform_now(@provider.slug, @payload)
    end

    policy = Policy.find_by(policy_number: "POL-WEBHOOK-1")
    assert policy
    assert_equal "producer", policy.sold_via
    assert_equal "purchased", @quote_result.quote.reload.status
  end

  test "processing the same webhook twice does not create a duplicate policy" do
    with_stubbed_client do
      assert_difference "Policy.count", 1 do
        WebhookProcessorJob.perform_now(@provider.slug, @payload)
        WebhookProcessorJob.perform_now(@provider.slug, @payload)
      end
    end
  end

  private

  def with_stubbed_client
    fake_client = @fake_client
    original_method = InsuranceProviders.method(:for)
    InsuranceProviders.define_singleton_method(:for) { |_provider| fake_client }
    yield
  ensure
    InsuranceProviders.define_singleton_method(:for, original_method)
  end
end
