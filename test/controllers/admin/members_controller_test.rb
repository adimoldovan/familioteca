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
  end
end
