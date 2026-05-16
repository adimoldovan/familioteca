require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "valid attributes" do
    book = Book.new(
      title: "Doi Ani de Vacanță",
      author: "Jules Verne",
      format: "epub",
      object_key: "verne/doi-ani.epub",
      ingested_at: Time.current
    )
    assert book.valid?, book.errors.full_messages.inspect
  end

  test "title is required" do
    book = Book.new(format: "epub", object_key: "a/b.epub", ingested_at: Time.current)
    refute book.valid?
    assert_includes book.errors[:title], "nu poate fi necompletat"
  end

  test "object_key is required and unique" do
    missing = Book.new(title: "A", format: "epub", ingested_at: Time.current)
    refute missing.valid?
    assert_includes missing.errors[:object_key], "nu poate fi necompletat"

    Book.create!(
      title: "A",
      format: "epub",
      object_key: "k1",
      ingested_at: Time.current,
      sort_title: "a",
      searchable: "a"
    )
    dup = Book.new(title: "B", format: "epub", object_key: "k1", ingested_at: Time.current)
    refute dup.valid?
    assert_includes dup.errors[:object_key], "este deja folosit"
  end

  test "ingested_at is required" do
    book = Book.new(title: "A", format: "epub", object_key: "k")
    refute book.valid?
    assert_includes book.errors[:ingested_at], "nu poate fi necompletat"
  end

  test "format must be epub, mobi, or pdf" do
    book = Book.new(title: "A", format: "txt", object_key: "k", ingested_at: Time.current)
    refute book.valid?
    assert_includes book.errors[:format], "nu este inclus în listă"
  end
end
