require "test_helper"

class Admin::InviteCodesControllerTest < ActionDispatch::IntegrationTest
  test "index lists all invite codes with status" do
    sign_in_as members(:admin)
    available = InviteCode.create!
    used = InviteCode.create!
    used.mark_used!(members(:ana))

    get admin_invite_codes_path
    assert_response :success
    assert_select "h1", "Coduri de invitație"
    assert_select ".admin-nav a[href='#{admin_invite_codes_path}'].admin-nav__link--active"
    assert_select ".admin-nav a[href='#{admin_books_path}']"
    assert_select ".admin-nav a[href='#{admin_members_path}']"
    assert_select "table tbody tr", 2
    assert_select "td code", text: available.code
    assert_select "td", text: "Activ"
    assert_select "td", text: "Folosit"
    assert_select "td", text: members(:ana).name
    assert_select "input[readonly][value='#{register_url(available.code)}']"
    assert_select "input[readonly]", count: 1
    assert_select "button[data-action='clipboard#copy']", text: "Copiază"
  end

  test "create generates a new code and redirects with URL in flash" do
    sign_in_as members(:admin)

    assert_difference "InviteCode.count", 1 do
      post admin_invite_codes_path
    end

    assert_redirected_to admin_invite_codes_path
    follow_redirect!
    code = InviteCode.last
    assert_includes flash[:notice], register_url(code.code)
  end

  test "create retries on code collision and succeeds" do
    sign_in_as members(:admin)
    existing = InviteCode.create!

    call_count = 0
    original = SecureRandom.method(:alphanumeric)
    SecureRandom.define_singleton_method(:alphanumeric) do |*args|
      call_count += 1
      call_count == 1 ? existing.code : original.call(*args)
    end

    assert_difference "InviteCode.count", 1 do
      post admin_invite_codes_path
    end

    assert_redirected_to admin_invite_codes_path
    follow_redirect!
    assert_includes flash[:notice], register_url(InviteCode.last.code)
  ensure
    SecureRandom.define_singleton_method(:alphanumeric, original)
  end

  test "create shows error after exhausting retries on code collision" do
    sign_in_as members(:admin)
    existing = InviteCode.create!

    original = SecureRandom.method(:alphanumeric)
    SecureRandom.define_singleton_method(:alphanumeric) { |*| existing.code }

    assert_no_difference "InviteCode.count" do
      post admin_invite_codes_path
    end

    assert_redirected_to admin_invite_codes_path
    follow_redirect!
    assert_select ".flash--alert", text: /încerci din nou/
  ensure
    SecureRandom.define_singleton_method(:alphanumeric, original)
  end

  test "index denied for non-admin" do
    sign_in_as members(:ana)
    get admin_invite_codes_path
    assert_response :not_found
  end

  test "create denied for non-admin" do
    sign_in_as members(:ana)
    post admin_invite_codes_path
    assert_response :not_found
  end

  test "index redirects unauthenticated user" do
    get admin_invite_codes_path
    assert_redirected_to sign_in_path
  end

  test "create redirects unauthenticated user" do
    post admin_invite_codes_path
    assert_redirected_to sign_in_path
  end
end
