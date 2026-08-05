require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root renders the public landing for Ruka without redirecting" do
    get root_path

    assert_response :success
    assert_select "form[action=?]", public_landing_path("ruka")
    assert_select "[data-quote-form-target=ages] [data-age-field]", 6
  end

  # La raíz es la landing pública para todo el mundo: con sesión abierta
  # tampoco redirige a un panel ni al login.
  test "root renders the landing for super admins too" do
    sign_in users(:admin_uno)
    get root_path

    assert_response :success
    assert_select "form[action=?]", public_landing_path("ruka")
  end

  test "root renders the landing for active producers too" do
    sign_in users(:producer_uno)
    get root_path

    assert_response :success
  end

  test "root renders the landing for pending producers too" do
    pending = users(:producer_uno)
    pending.update!(status: :pending)
    sign_in pending
    get root_path

    assert_response :success
  end
end
