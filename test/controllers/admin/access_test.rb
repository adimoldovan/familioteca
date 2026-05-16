require "test_helper"

class Admin::AccessTest < ActionDispatch::IntegrationTest
  test "admin reaches /admin/members successfully" do
    sign_in_as members(:admin)
    get admin_members_path
    assert_response :success
  end

  test "non-admin gets a 404 on /admin/members" do
    sign_in_as members(:ana)
    get admin_members_path
    assert_response :not_found
  end

  test "unauthenticated visitor is redirected to /sign_in" do
    get admin_members_path
    assert_redirected_to sign_in_path
  end
end
