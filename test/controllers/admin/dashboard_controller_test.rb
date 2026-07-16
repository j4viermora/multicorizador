require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows real policy totals by channel" do
    sign_in users(:admin_uno)
    get admin_dashboard_path

    assert_response :success
    assert_select ".stat-value", text: Policy.direct.count.to_s
    assert_select ".stat-value", text: Policy.producer_sold.count.to_s
  end
end
