require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "session belongs to a member" do
    member = members(:ana)
    session = Session.create!(member: member, token: SecureRandom.hex(32))
    assert_equal member, session.member
  end

  test "token is auto-generated on create when not provided" do
    session = Session.create!(member: members(:ana))
    assert_predicate session.token, :present?
    assert_equal 64, session.token.length
  end

  test "token presence is validated when explicitly set blank" do
    session = Session.new(member: members(:ana), token: "")
    refute session.valid?
    assert_includes session.errors[:token], "nu poate fi necompletat"
  end

  test "token must be unique" do
    Session.create!(member: members(:ana), token: "duplicate")
    other = Session.new(member: members(:admin), token: "duplicate")
    refute other.valid?
    assert_includes other.errors[:token], "este deja folosit"
  end

  test "member has many sessions" do
    member = members(:ana)
    Session.create!(member: member, token: SecureRandom.hex(32))
    Session.create!(member: member, token: SecureRandom.hex(32))
    assert_equal 2, member.sessions.count
  end

  test "destroying a member destroys its sessions" do
    member = members(:ana)
    Session.create!(member: member, token: SecureRandom.hex(32))
    Session.create!(member: member, token: SecureRandom.hex(32))
    assert_difference -> { Session.count }, -2 do
      member.destroy
    end
  end
end
