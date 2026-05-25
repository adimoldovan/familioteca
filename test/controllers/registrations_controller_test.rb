require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invite = InviteCode.create!
  end

  test "new renders the registration form for a valid code" do
    get register_path(code: @invite.code)
    assert_response :success
    assert_select "h1", I18n.t("registrations.new.title")
    assert_select "input[type=email]"
    assert_select "input[type=password]", count: 2
  end

  test "new redirects to sign_in for an invalid code" do
    get register_path(code: "INVALID")
    assert_redirected_to sign_in_path
    assert_equal I18n.t("registrations.invalid_code"), flash[:alert]
  end

  test "new redirects to sign_in for an already-used code" do
    @invite.update!(used_at: Time.current)
    get register_path(code: @invite.code)
    assert_redirected_to sign_in_path
  end

  test "new redirects to root if already signed in" do
    sign_in_as members(:ana)
    get register_path(code: @invite.code)
    assert_redirected_to root_path
  end

  test "create registers a new member and marks the code used" do
    assert_difference "Member.count", 1 do
      post register_path(code: @invite.code), params: {
        member: { name: "Bogdan", email: "bogdan@example.com",
                  password: "secret123", password_confirmation: "secret123" }
      }
    end
    assert_redirected_to root_path

    created = Member.find_by!(email: "bogdan@example.com")
    assert_equal "Bogdan", created.name
    refute created.admin?

    @invite.reload
    refute @invite.available?
    assert_equal created, @invite.used_by_member
  end

  test "create signs the new member in" do
    post register_path(code: @invite.code), params: {
      member: { name: "Bogdan", email: "bogdan@example.com",
                password: "secret123", password_confirmation: "secret123" }
    }
    follow_redirect!
    assert_select ".user-pill__name", text: "Bogdan"
  end

  test "create re-renders new with errors for invalid data" do
    assert_no_difference "Member.count" do
      post register_path(code: @invite.code), params: {
        member: { name: "", email: "not-an-email", password: "short", password_confirmation: "short" }
      }
    end
    assert_response :unprocessable_entity
    assert_select ".error-summary"
  end

  test "create rejects a used code" do
    @invite.update!(used_at: Time.current)
    assert_no_difference "Member.count" do
      post register_path(code: @invite.code), params: {
        member: { name: "X", email: "x@example.com",
                  password: "secret123", password_confirmation: "secret123" }
      }
    end
    assert_redirected_to sign_in_path
  end

  test "create rolls back member and redirects on concurrent code redemption" do
    original = InviteCode.instance_method(:mark_used!)
    InviteCode.define_method(:mark_used!) { |_m| raise InviteCode::AlreadyUsedError }

    assert_no_difference "Member.count" do
      post register_path(code: @invite.code), params: {
        member: { name: "Bogdan", email: "bogdan@example.com",
                  password: "secret123", password_confirmation: "secret123" }
      }
    end
    assert_redirected_to sign_in_path
    assert_equal I18n.t("registrations.invalid_code"), flash[:alert]
  ensure
    InviteCode.define_method(:mark_used!, original)
  end

  test "create rejects duplicate email" do
    assert_no_difference "Member.count" do
      post register_path(code: @invite.code), params: {
        member: { name: "Dup", email: "ana@example.com",
                  password: "secret123", password_confirmation: "secret123" }
      }
    end
    assert_response :unprocessable_entity
  end
end
