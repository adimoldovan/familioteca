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

  test "email is required" do
    member = Member.new(password: "secret123", name: "Ana")
    refute member.valid?
    assert_includes member.errors[:email], "nu poate fi necompletat"
  end

  test "email must be unique" do
    duplicate = Member.new(email: "ana@example.com", password: "secret123", name: "Other")
    refute duplicate.valid?
    assert_includes duplicate.errors[:email], "este deja folosit"
  end

  test "email must match a basic email format" do
    member = Member.new(email: "not-an-email", password: "secret123", name: "Ana")
    refute member.valid?
    assert_includes member.errors[:email], "este invalid"
  end

  test "password must be at least 8 characters" do
    member = Member.new(email: "new@example.com", password: "short", name: "Ana")
    refute member.valid?
    assert_includes member.errors[:password], "este prea scurt (minimum de caractere este 8)"
  end

  test "name is required" do
    member = Member.new(email: "new@example.com", password: "secret123")
    refute member.valid?
    assert_includes member.errors[:name], "nu poate fi necompletat"
  end

  test "kindle_email format is validated when present" do
    member = Member.new(
      email: "new@example.com",
      password: "secret123",
      name: "Ana",
      kindle_email: "not-an-email"
    )
    refute member.valid?
    assert_includes member.errors[:kindle_email], "este invalid"
  end

  test "kindle_email may be blank" do
    member = Member.new(
      email: "new@example.com",
      password: "secret123",
      name: "Ana",
      kindle_email: ""
    )
    assert member.valid?
  end

  test "generates a password_reset token that resolves back to the member" do
    member = members(:ana)
    token = member.generate_token_for(:password_reset)

    assert_kind_of String, token
    assert_equal member, Member.find_by_token_for(:password_reset, token)
  end

  test "password_reset token is invalid after password change" do
    member = members(:ana)
    token = member.generate_token_for(:password_reset)

    member.update!(password: "newsecret999")

    assert_nil Member.find_by_token_for(:password_reset, token)
  end

  test "password_reset token is invalid after 24 hours" do
    member = members(:ana)
    token = member.generate_token_for(:password_reset)

    travel 25.hours do
      assert_nil Member.find_by_token_for(:password_reset, token)
    end
  end
end
