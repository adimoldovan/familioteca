require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "unauthenticated request to root is redirected to /sign_in" do
    get root_path
    assert_redirected_to sign_in_path
  end

  test "authenticated request to root proceeds (does not redirect to /sign_in)" do
    sign_in_as members(:ana)
    get root_path
    assert_response :success
  end

  private

  def sign_in_as(member)
    session = member.sessions.create!
    cookies[:session_token] = session.token
  end
end
