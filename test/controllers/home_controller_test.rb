require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root renders the public landing for Ruka without redirecting" do
    get root_path

    assert_response :success
    assert_select "form[action=?]", public_landing_path("ruka")
    assert_select "[data-quote-form-target=ages] [data-age-field]", 6
  end

  test "root redirects super admins to admin dashboard" do
    sign_in users(:admin_uno)
    get root_path
    assert_redirected_to admin_dashboard_path
  end

  test "root redirects active producers to producer dashboard" do
    sign_in users(:producer_uno)
    get root_path
    assert_redirected_to producer_dashboard_path
  end

  test "root redirects pending producers to account pending" do
    pending = users(:producer_uno)
    pending.update!(status: :pending)
    sign_in pending
    get root_path
    assert_redirected_to account_pending_path
  end
end
