require "test_helper"

class Admin::ProvidersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provider = providers(:assist_card)
    @admin = users(:admin_uno)
  end

  test "el super admin activa un proveedor inactivo" do
    @provider.update!(status: "inactive")
    sign_in @admin

    patch toggle_active_admin_provider_path(@provider)

    assert_redirected_to admin_providers_path
    assert_equal "active", @provider.reload.status
  end

  test "el super admin desactiva un proveedor activo" do
    @provider.update!(status: "active")
    sign_in @admin

    patch toggle_active_admin_provider_path(@provider)

    assert_redirected_to admin_providers_path
    assert_equal "inactive", @provider.reload.status
  end

  test "el toggle preserva la configuración del proveedor" do
    omint = providers(:omint)
    config_before = omint.config
    sign_in @admin

    patch toggle_active_admin_provider_path(omint)

    assert_equal config_before, omint.reload.config,
      "las credenciales no deben tocarse al prender o apagar un proveedor"
    assert_equal "test-client-secret", omint.config["client_secret"]
  end

  test "un productor no puede alterar la activación" do
    @provider.update!(status: "active")
    sign_in users(:producer_uno)

    patch toggle_active_admin_provider_path(@provider)

    assert_response :redirect
    assert_not_equal admin_providers_path, response.location
    assert_equal "active", @provider.reload.status
  end

  test "un visitante sin sesión no puede alterar la activación" do
    @provider.update!(status: "active")

    patch toggle_active_admin_provider_path(@provider)

    assert_response :redirect
    assert_equal "active", @provider.reload.status
  end

  test "el listado distingue los proveedores que cotizan de los que no" do
    @provider.update!(status: "active")
    providers(:travel_ace).update!(status: "inactive")
    sign_in @admin

    get admin_providers_path

    assert_response :success
    assert_select ".badge-success", text: /Cotiza/
    assert_select ".badge-ghost", text: /No cotiza/
    assert_select "form[action=?]", toggle_active_admin_provider_path(@provider)
  end

  test "el listado avisa cuando no queda ningún proveedor activo" do
    Provider.update_all(status: "inactive")
    sign_in @admin

    get admin_providers_path

    assert_response :success
    assert_select "p", text: /No hay ninguno activo/
  end
end
