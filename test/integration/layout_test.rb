require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  test "layout shows app name and Romanian nav when signed in" do
    sign_in_as members(:ana)
    get root_path
    assert_response :success
    assert_select "html[lang=ro]"
    assert_select "header" do
      assert_select "a", I18n.t("app.name")
    end
    assert_select ".mobile-menu__nav a", I18n.t("navigation.catalog")
  end

  test "layout omits admin link for non-admins" do
    sign_in_as members(:ana)
    get root_path
    assert_select "a#nav-admin", count: 0
  end

  test "layout shows admin link for admins" do
    sign_in_as members(:admin)
    get root_path
    assert_select "a#nav-admin[href=?]", admin_books_path, text: I18n.t("navigation.admin")
  end

  test "layout shows sign-out button when signed in" do
    sign_in_as members(:ana)
    get root_path
    assert_select "button", I18n.t("sessions.destroy.link")
  end

  test "layout has no header for unauthenticated visitors" do
    get sign_in_path
    assert_response :success
    assert_select "header", false
  end
end
