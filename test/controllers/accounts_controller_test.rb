require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated visitor is redirected to /sign_in" do
    get account_path
    assert_redirected_to sign_in_path
  end

  test "show renders the account form with member data" do
    member = members(:ana)
    sign_in_as member

    get account_path
    assert_response :success
    assert_select ".crumbs__current", "Contul meu"
    assert_select "#account-name[value=?]", member.name
    assert_select "#account-email[value=?]", member.email
    assert_select "#account-kindle-email[value=?]", member.kindle_email
  end

  test "update saves name and kindle_email" do
    member = members(:ana)
    sign_in_as member

    patch account_path, params: { member: { name: "Ana Maria", kindle_email: "new@kindle.com" } }
    assert_redirected_to account_path
    follow_redirect!
    assert_select ".flash--notice", /Cont actualizat/

    member.reload
    assert_equal "Ana Maria", member.name
    assert_equal "new@kindle.com", member.kindle_email
  end

  test "update clears kindle_email when blank" do
    member = members(:ana)
    sign_in_as member

    patch account_path, params: { member: { name: "Ana", kindle_email: "" } }
    assert_redirected_to account_path

    member.reload
    assert_nil member.kindle_email
  end

  test "update re-renders form with errors when name is blank" do
    member = members(:ana)
    sign_in_as member

    patch account_path, params: { member: { name: "", kindle_email: "ana@kindle.com" } }
    assert_response :unprocessable_entity
    assert_select ".error-summary"
  end

  test "update re-renders form with errors when kindle_email is invalid" do
    member = members(:ana)
    sign_in_as member

    patch account_path, params: { member: { name: "Ana", kindle_email: "not-an-email" } }
    assert_response :unprocessable_entity
    assert_select ".error-summary"
  end

  test "update does not allow changing email" do
    member = members(:ana)
    sign_in_as member
    original_email = member.email

    patch account_path, params: { member: { name: "Ana", email: "hacker@evil.com" } }
    assert_redirected_to account_path

    member.reload
    assert_equal original_email, member.email
  end
end
