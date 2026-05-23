require "test_helper"

class MemberBookTest < ActiveSupport::TestCase
  setup do
    @member = members(:ana)
    @book = Book.create!(
      title: "A", format: "epub", object_key: "k1", ingested_at: Time.current
    )
  end

  test "valid with member and book" do
    mb = MemberBook.new(member: @member, book: @book)
    assert mb.valid?, mb.errors.full_messages.inspect
  end

  test "rating enum maps low->high" do
    assert_equal({ "nu_mi_a_placut" => 0, "asa_si_asa" => 1, "mi_a_placut" => 2 }, MemberBook.ratings)
  end

  test "assigning rating by symbol persists the integer" do
    mb = MemberBook.create!(member: @member, book: @book, rating: :mi_a_placut)
    assert_equal "mi_a_placut", mb.reload.rating
    assert_equal 2, mb.rating_before_type_cast
  end

  test "rating can be nil (un-rated)" do
    mb = MemberBook.create!(member: @member, book: @book, rating: :asa_si_asa)
    mb.update!(rating: nil)
    assert_nil mb.reload.rating
  end

  test "read? is true when read_at is set" do
    mb = MemberBook.new(member: @member, book: @book)
    refute mb.read?
    mb.read_at = Time.current
    assert mb.read?
  end

  test "duplicate (member, book) pair is rejected at the DB" do
    MemberBook.create!(member: @member, book: @book)
    assert_raises(ActiveRecord::RecordNotUnique) do
      MemberBook.new(member: @member, book: @book).save!(validate: false)
    end
  end

  test "uniqueness validation surfaces the same conflict before DB" do
    MemberBook.create!(member: @member, book: @book)
    dup = MemberBook.new(member: @member, book: @book)
    refute dup.valid?
    assert_includes dup.errors[:member_id], "este deja folosit"
  end
end
