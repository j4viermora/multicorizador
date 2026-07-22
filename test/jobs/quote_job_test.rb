require "test_helper"

class QuoteJobTest < ActiveJob::TestCase
  setup do
    @company = companies(:ruka)
    ActsAsTenant.current_tenant = @company

    @quote = Quote.create!(
      company: @company,
      producer: users(:producer_uno),
      status: "draft",
      origin: "EZE",
      destination: "MIA",
      departure_date: 30.days.from_now.to_date,
      return_date: 40.days.from_now.to_date,
      travelers_count: 1,
      metadata: { "ages" => [ 35 ] }
    )
  end

  teardown do
    ActsAsTenant.current_tenant = nil
  end

  test "encola un job por proveedor activo y registra cuántos espera" do
    active_count = Provider.active.count

    assert_enqueued_jobs active_count, only: ProviderQuoteJob do
      QuoteJob.perform_now(@quote.id)
    end

    @quote.reload
    assert_equal "quoting", @quote.status
    assert_equal active_count, @quote.expected_providers_count
  end

  test "no encola nada para los proveedores inactivos" do
    Provider.update_all(status: "inactive")
    providers(:assist_card).update!(status: "active")

    assert_enqueued_jobs 1, only: ProviderQuoteJob do
      QuoteJob.perform_now(@quote.id)
    end

    assert_equal 1, @quote.reload.expected_providers_count
  end

  test "sin proveedores activos cierra la cotización en lugar de dejarla colgada" do
    Provider.update_all(status: "inactive")

    assert_no_enqueued_jobs only: ProviderQuoteJob do
      QuoteJob.perform_now(@quote.id)
    end

    @quote.reload
    assert_equal "no_results", @quote.status,
      "sin proveedores nadie llegaría a cerrarla y quedaría en quoting para siempre"
    assert_equal 0, @quote.expected_providers_count
  end

  test "ignora una cotización que ya no está en borrador" do
    @quote.update!(status: "quoted")

    assert_no_enqueued_jobs only: ProviderQuoteJob do
      QuoteJob.perform_now(@quote.id)
    end
  end
end
