require "test_helper"

class Admin::MembersControllerTest < ActionDispatch::IntegrationTest
  test "lists all members in a table" do
    sign_in_as members(:admin)
    get admin_members_path
    assert_response :success
    assert_select "h1", "Membri"
    assert_select "th", text: "Nume"
    assert_select "th", text: "Email"
    assert_select "th", text: "Email Kindle"
    assert_select "th", text: "Rol"
    assert_select "table tbody tr", 2
    assert_select "td", text: "Ana"
    assert_select "td", text: "Administrator"
    assert_select "td", text: "ana@example.com"
    assert_select "td", text: "admin@example.com"
    assert_select "td", text: "Membru", count: 1
    assert_select "tbody tr td:nth-child(3)", text: "ana@kindle.com", count: 1
    assert_select "tbody tr td:nth-child(3)", text: "—", count: 1
    assert_select "#admin-scan-button #scan-now-button"
  end

  test "reset_link generates token and displays URL" do
    sign_in_as members(:admin)
    post reset_link_admin_member_path(members(:ana))
    assert_response :success
    assert_select "#reset-url" do |elements|
      assert_match %r{/password_resets/[^/]+/edit}, elements.first.text
    end
  end

  test "reset_link denied for non-admin" do
    sign_in_as members(:ana)
    post reset_link_admin_member_path(members(:ana))
    assert_response :not_found
  end
end
