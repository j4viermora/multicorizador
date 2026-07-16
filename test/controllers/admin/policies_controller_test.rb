require "test_helper"

class Admin::PoliciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_uno)
    @producer = users(:producer_uno)
  end

  test "admin sees policies across every company/tenant" do
    sign_in @admin
    get admin_policies_path

    assert_response :success
    assert_includes @response.body, policies(:direct_policy).policy_number
    assert_includes @response.body, policies(:producer_policy).policy_number
  end

  test "filtering by sold_via returns only the matching channel" do
    sign_in @admin
    get admin_policies_path(q: { sold_via_eq: "direct" })

    assert_response :success
    assert_includes @response.body, policies(:direct_policy).policy_number
    assert_not_includes @response.body, policies(:producer_policy).policy_number
  end

  test "a producer cannot access the admin policies list" do
    sign_in @producer
    get admin_policies_path

    assert_redirected_to root_path
  end
end
