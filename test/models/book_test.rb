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
      ingested_at: Time.current
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

  test "sort_title is the diacritic-folded title" do
    book = Book.create!(
      title: "Țara de Dincolo",
      format: "epub",
      object_key: "k",
      ingested_at: Time.current
    )
    assert_equal "tara de dincolo", book.sort_title
  end

  test "searchable concatenates folded title, author, description" do
    book = Book.create!(
      title: "Cărți Bune",
      author: "Mihai Eminescu",
      description: "Despre Bizanț și mănăstiri.",
      format: "epub",
      object_key: "k",
      ingested_at: Time.current
    )
    assert_includes book.searchable, "carti bune"
    assert_includes book.searchable, "mihai eminescu"
    assert_includes book.searchable, "bizant"
    assert_includes book.searchable, "manastiri"
  end

  test "sort_title and searchable refresh on update" do
    book = Book.create!(
      title: "Old Title",
      format: "epub",
      object_key: "k",
      ingested_at: Time.current
    )
    book.update!(title: "Țara")
    assert_equal "tara", book.sort_title
    assert_includes book.searchable, "tara"
  end
end
