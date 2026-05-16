require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  test "signed-in member sees the empty catalog placeholder" do
    sign_in_as members(:ana)
    get root_path
    assert_response :success
    assert_select "h1", "Bibliotecă"
    assert_select "p", "Niciun titlu disponibil"
  end

  test "unauthenticated visitor is redirected to /sign_in" do
    get root_path
    assert_redirected_to sign_in_path
  end
end
