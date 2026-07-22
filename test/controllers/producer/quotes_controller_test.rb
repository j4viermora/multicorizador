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
end
