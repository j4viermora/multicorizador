require "test_helper"

class DirectSaleFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @company = companies(:ruka)
  end

  test "quoting from the public landing uses the same async engine as the producer flow" do
    perform_enqueued_jobs do
      post public_landing_path(@company.slug), params: {
        quote: {
          origin: "EZE",
          destination: "MIA",
          departure_date: 30.days.from_now.to_date,
          return_date: 40.days.from_now.to_date,
          travelers_count: 2,
          trip_type: "single",
          metadata: { email: "cliente@example.com", ages: [ 30, 32 ] }
        }
      }
    end

    assert_response :redirect

    token = response.location[%r{/resultados/([^/?]+)}, 1]
    quote = Quote.find_by!(public_token: token)
    assert_equal "quoted", quote.status
    assert quote.quote_results.successful.count.positive?

    follow_redirect!
    assert_response :success
  end

  test "a quote with no successful provider responses does not end up quoted" do
    provider = providers(:assist_card)
    failing_client = Object.new
    failing_client.define_singleton_method(:quote) { |_quote| raise InsuranceProviders::BaseProvider::ProviderError, "boom" }

    original_provider_active = Provider.method(:active)
    Provider.define_singleton_method(:active) { Provider.where(id: provider.id) }

    original_for = InsuranceProviders.method(:for)
    InsuranceProviders.define_singleton_method(:for) { |_provider| failing_client }

    perform_enqueued_jobs do
      post public_landing_path(@company.slug), params: {
        quote: {
          origin: "USH",
          destination: "BRC",
          departure_date: 10.days.from_now.to_date,
          return_date: 15.days.from_now.to_date,
          travelers_count: 1,
          trip_type: "single",
          metadata: { email: "cliente2@example.com" }
        }
      }
    end

    token = response.location[%r{/resultados/([^/?]+)}, 1]
    quote = Quote.find_by!(public_token: token)
    assert_equal "no_results", quote.status
    assert quote.quote_results.successful.empty?
  ensure
    Provider.define_singleton_method(:active, original_provider_active) if original_provider_active
    InsuranceProviders.define_singleton_method(:for, original_for) if original_for
  end
end
