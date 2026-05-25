require "test_helper"

class InviteCodeTest < ActiveSupport::TestCase
  test "auto-generates 8-char alphanumeric code on create" do
    invite = InviteCode.create!
    assert_equal 8, invite.code.length
    assert_match(/\A[a-zA-Z0-9]{8}\z/, invite.code)
  end

  test "does not overwrite an explicitly provided code" do
    invite = InviteCode.create!(code: "CUSTOM01")
    assert_equal "CUSTOM01", invite.code
  end

  test "code must be unique" do
    InviteCode.create!(code: "DUPE1234")
    duplicate = InviteCode.new(code: "DUPE1234")
    refute duplicate.valid?
    assert_includes duplicate.errors[:code], "este deja folosit"
  end

  test "code uniqueness is enforced by the database" do
    InviteCode.create!(code: "UNIQ1234")
    assert_raises(ActiveRecord::RecordNotUnique) do
      InviteCode.new(code: "UNIQ1234").save(validate: false)
    end
  end

  test "available? returns true when used_at is nil" do
    invite = InviteCode.create!
    assert invite.available?
  end

  test "available? returns false after mark_used!" do
    invite = InviteCode.create!
    invite.mark_used!(members(:ana))
    refute invite.available?
  end

  test "mark_used! raises when code is already used" do
    invite = InviteCode.create!
    invite.mark_used!(members(:ana))
    assert_raises(InviteCode::AlreadyUsedError) { invite.mark_used!(members(:admin)) }
  end

  test "mark_used! sets used_at and used_by_member" do
    invite = InviteCode.create!
    member = members(:ana)

    freeze_time do
      invite.mark_used!(member)
      assert_equal Time.current, invite.used_at
      assert_equal member, invite.used_by_member
    end
  end

  test "available scope returns only unused codes" do
    available = InviteCode.create!
    used = InviteCode.create!
    used.mark_used!(members(:ana))

    assert_includes InviteCode.available, available
    refute_includes InviteCode.available, used
  end

  test "used scope returns only used codes" do
    available = InviteCode.create!
    used = InviteCode.create!
    used.mark_used!(members(:ana))

    assert_includes InviteCode.used, used
    refute_includes InviteCode.used, available
  end

  test "DB nullifies used_by_member_id when member is deleted directly" do
    code = InviteCode.create!
    code.mark_used!(members(:ana))

    Member.where(id: members(:ana).id).delete_all

    assert_nil code.reload.used_by_member_id
  end
end
