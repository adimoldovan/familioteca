require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = members(:ana)
    @token = @member.generate_token_for(:password_reset)
  end

  test "GET edit renders password form for valid token" do
    get edit_password_reset_path(token: @token)
    assert_response :success
    assert_select "h1", "Resetare parolă"
    assert_select "label", "Parolă nouă"
    assert_select "label", "Confirmă parola"
    assert_select "input[type=submit][value=?]", "Salvează parola"
  end

  test "GET edit with invalid token redirects to sign_in" do
    get edit_password_reset_path(token: "bogus")
    assert_redirected_to sign_in_path
    assert_equal "Link-ul de resetare a expirat sau este invalid.", flash[:alert]
  end

  test "GET edit with expired token redirects to sign_in" do
    token = travel_to(25.hours.ago) { @member.generate_token_for(:password_reset) }
    get edit_password_reset_path(token: token)
    assert_redirected_to sign_in_path
    assert_equal "Link-ul de resetare a expirat sau este invalid.", flash[:alert]
  end

  test "PATCH update sets new password and redirects to sign_in" do
    patch password_reset_path(token: @token), params: {
      member: { password: "newsecret1", password_confirmation: "newsecret1" }
    }
    assert_redirected_to sign_in_path
    assert_equal "Parola a fost schimbată. Te poți autentifica.", flash[:notice]
    assert @member.reload.authenticate("newsecret1")
  end

  test "PATCH update with invalid token redirects to sign_in" do
    patch password_reset_path(token: "bogus"), params: {
      member: { password: "newsecret1", password_confirmation: "newsecret1" }
    }
    assert_redirected_to sign_in_path
    assert_equal "Link-ul de resetare a expirat sau este invalid.", flash[:alert]
  end

  test "PATCH update with short password re-renders form" do
    patch password_reset_path(token: @token), params: {
      member: { password: "short", password_confirmation: "short" }
    }
    assert_response :unprocessable_entity
    assert_select ".error-summary"
  end

  test "PATCH update with mismatched passwords re-renders form" do
    patch password_reset_path(token: @token), params: {
      member: { password: "newsecret1", password_confirmation: "different1" }
    }
    assert_response :unprocessable_entity
    assert_select ".error-summary"
  end

  test "token is invalidated after successful password change" do
    patch password_reset_path(token: @token), params: {
      member: { password: "newsecret1", password_confirmation: "newsecret1" }
    }
    assert_redirected_to sign_in_path

    get edit_password_reset_path(token: @token)
    assert_redirected_to sign_in_path
    assert_equal "Link-ul de resetare a expirat sau este invalid.", flash[:alert]
  end
end
