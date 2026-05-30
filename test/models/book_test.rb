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

  test "searchable concatenates folded title and author only" do
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
    refute_includes book.searchable, "bizant"
    refute_includes book.searchable, "manastiri"
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

  test "needs_rescan scope returns visible books whose file changed after the last DB write" do
    stale  = Book.create!(title: "Stale", format: "epub", object_key: "k1", ingested_at: 1.week.ago,
                          file_modified_at: 1.minute.from_now)
    fresh  = Book.create!(title: "Fresh", format: "epub", object_key: "k2", ingested_at: 1.week.ago,
                          file_modified_at: 1.minute.ago)
    never  = Book.create!(title: "Never", format: "epub", object_key: "k3", ingested_at: Time.current)
    hidden = Book.create!(title: "Hidden", format: "epub", object_key: "k4", ingested_at: 1.week.ago,
                          file_modified_at: 1.minute.from_now, missing_since: Time.current)

    needs = Book.needs_rescan
    assert_includes needs, stale
    refute_includes needs, fresh  # file older than the last DB write
    refute_includes needs, never  # no recorded file time yet
    refute_includes needs, hidden # not visible (missing from archive)
  end

  test "needs_rescan? is false without a recorded file time" do
    book = Book.new(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    refute book.needs_rescan?
  end

  test "a DB write later than the file time clears needs_rescan" do
    book = Book.create!(title: "Stale", format: "epub", object_key: "k1", ingested_at: 1.week.ago,
                        file_modified_at: 1.minute.from_now)
    assert book.needs_rescan?, "precondition: book should start flagged"

    # A rescan (or any save) moves updated_at past the file time, clearing the flag.
    travel 2.minutes do
      book.touch
    end

    refute book.reload.needs_rescan?
    refute_includes Book.needs_rescan, book
  end

  test "goodreads_url accepts valid Goodreads URLs" do
    book = Book.new(title: "T", format: "epub", object_key: "k", ingested_at: Time.current,
                    goodreads_url: "https://www.goodreads.com/book/show/12345")
    assert book.valid?, book.errors.full_messages.inspect
  end

  test "goodreads_url rejects non-Goodreads URLs" do
    book = Book.new(title: "T", format: "epub", object_key: "k", ingested_at: Time.current,
                    goodreads_url: "https://example.com/book")
    refute book.valid?
    assert_includes book.errors[:goodreads_url], "este invalid"
  end

  test "goodreads_url rejects javascript: URI" do
    book = Book.new(title: "T", format: "epub", object_key: "k", ingested_at: Time.current,
                    goodreads_url: "javascript:alert(1)")
    refute book.valid?
    assert_includes book.errors[:goodreads_url], "este invalid"
  end

  test "goodreads_url allows blank" do
    book = Book.new(title: "T", format: "epub", object_key: "k", ingested_at: Time.current,
                    goodreads_url: "")
    assert book.valid?, book.errors.full_messages.inspect
  end

  test "needs_goodreads scope returns visible books without a goodreads_url" do
    with_url    = Book.create!(title: "A", format: "epub", object_key: "k1", ingested_at: Time.current,
                               goodreads_url: "https://www.goodreads.com/book/show/1")
    without_url = Book.create!(title: "B", format: "epub", object_key: "k2", ingested_at: Time.current)
    hidden      = Book.create!(title: "C", format: "epub", object_key: "k3", ingested_at: Time.current,
                               missing_since: Time.current)

    needs = Book.needs_goodreads
    assert_includes needs, without_url
    refute_includes needs, with_url
    refute_includes needs, hidden
  end

  test "search scope matches diacritic-insensitively" do
    Book.create!(title: "Bizanț", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Cluj",   format: "epub", object_key: "k2", ingested_at: Time.current)
    results = Book.search("bizant")
    assert_equal 1, results.count
    assert_equal "Bizanț", results.first.title
  end

  test "by_language scope filters by single language" do
    Book.create!(title: "A", language: "Romanian", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: "English",  format: "epub", object_key: "k2", ingested_at: Time.current)
    Book.create!(title: "C", language: nil,  format: "epub", object_key: "k3", ingested_at: Time.current)

    assert_equal 1, Book.by_language("Romanian").count
    assert_equal 1, Book.by_language("English").count
  end

  test "by_language scope filters by multiple languages" do
    Book.create!(title: "A", language: "Romanian", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: "English",  format: "epub", object_key: "k2", ingested_at: Time.current)
    Book.create!(title: "C", language: "French",   format: "epub", object_key: "k3", ingested_at: Time.current)

    assert_equal 2, Book.by_language(%w[Romanian English]).count
  end

  test "by_language scope returns all when blank or empty" do
    Book.create!(title: "A", language: "Romanian", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: nil,  format: "epub", object_key: "k2", ingested_at: Time.current)

    assert_equal 2, Book.by_language("").count
    assert_equal 2, Book.by_language(nil).count
    assert_equal 2, Book.by_language([]).count
  end

  test "available_languages returns sorted distinct normalized languages from visible books" do
    Book.create!(title: "A", language: "ro",    format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: "en",    format: "epub", object_key: "k2", ingested_at: Time.current)
    Book.create!(title: "C", language: "ro-RO", format: "epub", object_key: "k3", ingested_at: Time.current)
    Book.create!(title: "D", language: nil,     format: "epub", object_key: "k4", ingested_at: Time.current)
    Book.create!(title: "E", language: "fr",    format: "epub", object_key: "k5", ingested_at: Time.current,
                  missing_since: Time.current)

    assert_equal %w[English Romanian], Book.available_languages
  end

  test "normalizes language codes on save" do
    book = Book.create!(title: "A", language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    assert_equal "Romanian", book.language

    book.update!(language: "en-US")
    assert_equal "English", book.language

    book.update!(language: "French")
    assert_equal "French", book.language

    book.update!(language: nil)
    assert_nil book.language
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

  test "member_book_for returns the existing row when present" do
    book = Book.create!(title: "A", format: "epub", object_key: "k", ingested_at: Time.current)
    existing = MemberBook.create!(member: members(:ana), book: book, rating: :mi_a_placut)
    assert_equal existing, book.member_book_for(members(:ana))
  end

  test "member_book_for returns a fresh, unpersisted row when none exists" do
    book = Book.create!(title: "A", format: "epub", object_key: "k", ingested_at: Time.current)
    mb = book.member_book_for(members(:ana))
    refute_nil mb
    assert mb.new_record?
    assert_equal members(:ana), mb.member
    assert_equal book, mb.book
  end

  test "oversize_for_kindle? is true above 24MB" do
    book = Book.create!(
      title: "Big", format: "epub", object_key: "kindle-big", ingested_at: Time.current,
      file_size: 25.megabytes
    )
    assert book.oversize_for_kindle?
  end

  test "oversize_for_kindle? is false at 24MB exactly" do
    book = Book.create!(
      title: "Edge", format: "epub", object_key: "kindle-edge", ingested_at: Time.current,
      file_size: 24.megabytes
    )
    refute book.oversize_for_kindle?
  end

  test "oversize_for_kindle? is false when file_size is nil (unknown — let the send attempt fail loudly)" do
    book = Book.create!(
      title: "?", format: "epub", object_key: "kindle-nil", ingested_at: Time.current
    )
    refute book.oversize_for_kindle?
  end

  test "reading_minutes rounds up to whole minutes" do
    book = Book.new(word_count: 500)
    assert_equal 3, book.reading_minutes(200) # 2.5 → 3
  end

  test "reading_minutes is nil without a word count" do
    assert_nil Book.new(word_count: nil).reading_minutes(200)
  end

  test "reading_minutes is nil for a non-positive reading speed" do
    book = Book.new(word_count: 500)
    assert_nil book.reading_minutes(0)
    assert_nil book.reading_minutes(-100)
  end

  test "book has many kindle_deliveries and destroys them when the book is destroyed" do
    book = Book.create!(title: "T", format: "epub", object_key: "kindle-assoc", ingested_at: Time.current)
    KindleDelivery.create!(member: members(:ana), book: book)
    assert_equal 1, book.kindle_deliveries.count
    assert_difference "KindleDelivery.count", -1 do
      book.destroy
    end
  end

  test "sync_categories sets the book's categories" do
    book = Book.create!(title: "T", format: "epub", object_key: "cat-1", ingested_at: Time.current)
    book.sync_categories(%w[fiction biography])
    assert_equal %w[biography fiction], book.category_keys.sort
  end

  test "sync_categories adds and removes only what changed, keeping kept rows" do
    book = Book.create!(title: "T", format: "epub", object_key: "cat-2", ingested_at: Time.current)
    book.sync_categories(%w[fiction non_fiction])
    kept = book.book_categories.find_by(category: "fiction")

    book.sync_categories(%w[fiction biography])

    assert_equal %w[biography fiction], book.category_keys.sort
    assert_equal kept.id, book.book_categories.find_by(category: "fiction").id
  end

  test "sync_categories is correct even when the association is already loaded" do
    book = Book.create!(title: "T", format: "epub", object_key: "cat-stale", ingested_at: Time.current)
    book.sync_categories(%w[fiction])
    book.category_keys # force-load the association cache

    book.sync_categories(%w[fiction biography])
    assert_equal %w[biography fiction], book.category_keys.sort
  end

  test "sync_categories ignores unknown keys and clears on empty" do
    book = Book.create!(title: "T", format: "epub", object_key: "cat-3", ingested_at: Time.current)
    book.sync_categories(%w[fiction bogus])
    assert_equal %w[fiction], book.category_keys

    book.sync_categories([])
    assert_empty book.category_keys
  end

  test "destroying a book destroys its categories" do
    book = Book.create!(title: "T", format: "epub", object_key: "cat-4", ingested_at: Time.current)
    book.sync_categories(%w[fiction])
    assert_difference "BookCategory.count", -1 do
      book.destroy
    end
  end

  test "without_category returns only visible books with no categories" do
    with = Book.create!(title: "With", format: "epub", object_key: "cat-5", ingested_at: Time.current)
    with.sync_categories(%w[fiction])
    without = Book.create!(title: "Without", format: "epub", object_key: "cat-6", ingested_at: Time.current)
    missing = Book.create!(title: "Missing", format: "epub", object_key: "cat-5b", ingested_at: Time.current,
                           missing_since: Time.current)

    assert_includes Book.without_category, without
    refute_includes Book.without_category, with     # has a category
    refute_includes Book.without_category, missing  # not visible
  end

  test "by_category matches books in any of the given categories" do
    fic = Book.create!(title: "Fic", format: "epub", object_key: "cat-7", ingested_at: Time.current)
    fic.sync_categories(%w[fiction])
    bio = Book.create!(title: "Bio", format: "epub", object_key: "cat-8", ingested_at: Time.current)
    bio.sync_categories(%w[biography])

    result = Book.by_category(%w[fiction biography])
    assert_includes result, fic
    assert_includes result, bio
  end

  test "by_category with no valid categories returns all books" do
    book = Book.create!(title: "T", format: "epub", object_key: "cat-9", ingested_at: Time.current)
    assert_includes Book.by_category([]), book
    assert_includes Book.by_category(%w[bogus]), book
  end

  test "BookCategory rejects duplicates and unknown categories" do
    book = Book.create!(title: "T", format: "epub", object_key: "cat-10", ingested_at: Time.current)
    book.book_categories.create!(category: "fiction")
    assert_not book.book_categories.build(category: "fiction").valid?
    assert_not book.book_categories.build(category: "bogus").valid?
  end
end
