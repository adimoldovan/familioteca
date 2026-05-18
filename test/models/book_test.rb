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

  test "visible scope excludes books that are missing or have parse errors" do
    shown   = Book.create!(title: "Shown",   format: "epub", object_key: "k1", ingested_at: Time.current)
    missing = Book.create!(title: "Missing", format: "epub", object_key: "k2", ingested_at: Time.current,
                            missing_since: Time.current)
    broken  = Book.create!(title: "Broken",  format: "epub", object_key: "k3", ingested_at: Time.current,
                            parse_error: "Could not read EPUB metadata")
    visible = Book.visible
    assert_includes visible, shown
    refute_includes visible, missing
    refute_includes visible, broken
  end

  test "needs_metadata scope returns books with parse_error" do
    good = Book.create!(title: "Good", format: "epub", object_key: "k1", ingested_at: Time.current)
    bad  = Book.create!(title: "bad.epub", format: "epub", object_key: "k2", ingested_at: Time.current,
                         parse_error: "Could not read EPUB metadata")
    needs = Book.needs_metadata
    assert_includes needs, bad
    refute_includes needs, good
  end

  test "search scope matches diacritic-insensitively" do
    Book.create!(title: "Bizanț", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Cluj",   format: "epub", object_key: "k2", ingested_at: Time.current)
    results = Book.search("bizant")
    assert_equal 1, results.count
    assert_equal "Bizanț", results.first.title
  end

  test "search scope returns all books when query is blank" do
    Book.create!(title: "A", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", format: "epub", object_key: "k2", ingested_at: Time.current)
    assert_equal 2, Book.search("").count
    assert_equal 2, Book.search(nil).count
  end

  test "cover_thumbnail is nil without a cover, and a variant once one is attached" do
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    assert_nil book.cover_thumbnail

    # EPUB fixture is reused as the cover blob; identify: false keeps the declared
    # content_type so the variant is requestable without a real image fixture.
    book.cover.attach(
      io: File.open(Rails.root.join("test/fixtures/files/ebooks/well-tagged.epub")),
      filename: "cover.png",
      content_type: "image/png",
      identify: false
    )
    variant = book.cover_thumbnail
    refute_nil variant
    assert_kind_of ActiveStorage::VariantWithRecord, variant
  end

  test "cover_thumbnail is nil when the attached cover is not variable" do
    book = Book.create!(title: "T", format: "epub", object_key: "k3", ingested_at: Time.current)
    book.cover.attach(
      io: StringIO.new("opaque-bytes"),
      filename: "#{book.id}-cover.bin",
      content_type: "application/octet-stream",
      identify: false
    )

    assert book.cover.attached?
    assert_nil book.cover_thumbnail
  end
end
