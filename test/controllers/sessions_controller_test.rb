require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /sign_in renders the form with Romanian labels" do
    get sign_in_path
    assert_response :success
    assert_select "h1", "Autentificare"
    assert_select "label", "Email"
    assert_select "label", "Parolă"
    assert_select "input[type=submit][value=?]", "Intră în cont"
  end

  test "POST /session with valid credentials signs the member in and redirects to root" do
    post session_path, params: { email: "ana@example.com", password: "secret123" }
    assert_redirected_to root_path
    assert_not_nil cookies[:session_token].presence
    follow_redirect!
    assert_response :success
  end

  test "POST /session normalizes the email before lookup" do
    post session_path, params: { email: "  ANA@Example.com  ", password: "secret123" }
    assert_redirected_to root_path
  end

  test "POST /session with invalid credentials re-renders form with error" do
    post session_path, params: { email: "ana@example.com", password: "wrong" }
    assert_response :unprocessable_entity
    assert_select "p.flash-error", "Email sau parolă greșite."
  end

  test "POST /session with unknown email re-renders form with error" do
    post session_path, params: { email: "nobody@example.com", password: "anything" }
    assert_response :unprocessable_entity
    assert_select "p.flash-error", "Email sau parolă greșite."
  end

  test "DELETE /session signs the member out" do
    sign_in_as members(:ana)
    delete session_path
    assert_redirected_to sign_in_path
    assert_nil cookies[:session_token].presence
  end
end
