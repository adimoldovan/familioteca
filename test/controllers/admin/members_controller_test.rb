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

  test "index shows invite codes link" do
    sign_in_as members(:admin)
    get admin_members_path
    assert_select "a[href='#{admin_invite_codes_path}']", text: "Coduri de invitație"
  end

  test "index shows delete button for other members but not for self" do
    sign_in_as members(:admin)
    get admin_members_path
    assert_select "form[action='#{admin_member_path(members(:ana))}'] button", text: "Șterge"
    assert_select "form[action='#{admin_member_path(members(:admin))}'] button", text: "Șterge", count: 0
  end

  test "destroy removes a member and redirects" do
    sign_in_as members(:admin)
    assert_difference "Member.count", -1 do
      delete admin_member_path(members(:ana))
    end
    assert_redirected_to admin_members_path
    assert_equal "Membrul a fost șters.", flash[:notice]
  end

  test "destroy self redirects with error" do
    sign_in_as members(:admin)
    assert_no_difference "Member.count" do
      delete admin_member_path(members(:admin))
    end
    assert_redirected_to admin_members_path
    assert_equal "Nu te poți șterge pe tine.", flash[:alert]
  end

  test "destroy nullifies used invite codes" do
    sign_in_as members(:admin)
    code = InviteCode.create!(code: "TEST1234")
    code.update!(used_by_member: members(:ana), used_at: Time.current)

    delete admin_member_path(members(:ana))
    assert_redirected_to admin_members_path
    assert_nil code.reload.used_by_member_id
  end

  test "destroy denied for non-admin" do
    sign_in_as members(:ana)
    assert_no_difference "Member.count" do
      delete admin_member_path(members(:ana))
    end
    assert_response :not_found
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
