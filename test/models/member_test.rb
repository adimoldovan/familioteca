require "test_helper"

class MemberTest < ActiveSupport::TestCase
  test "valid member can be created with or without kindle_email" do
    without_kindle = Member.new(email: "new@example.com", password: "secret123", name: "Ana")
    assert without_kindle.valid?, without_kindle.errors.full_messages.inspect

    with_kindle = Member.new(email: "other@example.com", password: "secret123", name: "Bob", kindle_email: "bob@kindle.com")
    assert with_kindle.valid?, with_kindle.errors.full_messages.inspect
  end

  test "admin defaults to false" do
    member = Member.create!(
      email: "new@example.com",
      password: "secret123",
      name: "Ana"
    )
    assert_equal false, member.admin?
  end

  test "password is hashed via has_secure_password" do
    member = Member.create!(
      email: "new@example.com",
      password: "secret123",
      name: "Ana"
    )
    refute_equal "secret123", member.password_digest
    assert member.authenticate("secret123")
    refute member.authenticate("wrong")
  end

  test "email uniqueness is enforced by the database" do
    Member.create!(email: "dup@example.com", password: "secret123", name: "First")
    duplicate = Member.new(email: "dup@example.com", password: "secret123", name: "Second")
    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save(validate: false)
    end
  end
end
