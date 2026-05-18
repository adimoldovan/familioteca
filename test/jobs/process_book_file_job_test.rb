require "test_helper"
require "tempfile"

class ProcessBookFileJobTest < ActiveJob::TestCase
  FIXTURES = Rails.root.join("test/fixtures/files/ebooks").freeze

  test "creates a Book from a well-tagged EPUB and attaches the cover" do
    storage = stub_storage("verne/doi-ani.epub", FIXTURES.join("well-tagged.epub"))

    assert_difference "Book.count", 1 do
      ProcessBookFileJob.new.perform("verne/doi-ani.epub", storage: storage)
    end

    book = Book.find_by!(object_key: "verne/doi-ani.epub")
    assert_equal "Doi Ani de Vacanță", book.title
    assert_equal "Jules Verne", book.author
    assert_equal "epub", book.format
    assert book.cover.attached?
    refute_nil book.ingested_at
    assert_nil book.parse_error
  end

  test "stores parse_error when EPUB is unreadable, deriving title from object_key" do
    storage = stub_storage("broken/Autor - Carte rupta.epub", FIXTURES.join("corrupt.epub"))

    ProcessBookFileJob.new.perform("broken/Autor - Carte rupta.epub", storage: storage)

    book = Book.find_by!(object_key: "broken/Autor - Carte rupta.epub")
    assert_equal "Carte rupta", book.title
    assert_equal "Autor", book.author
    assert_match(/Could not parse EPUB/, book.parse_error)
    refute book.cover.attached?
  end

  test "re-running clears a previous parse_error and attaches the cover" do
    broken_storage = stub_storage("k/b.epub", FIXTURES.join("corrupt.epub"))
    ProcessBookFileJob.new.perform("k/b.epub", storage: broken_storage)
    book = Book.find_by!(object_key: "k/b.epub")
    refute_nil book.parse_error
    refute book.cover.attached?

    healthy_storage = stub_storage("k/b.epub", FIXTURES.join("well-tagged.epub"))
    assert_no_difference "Book.count" do
      ProcessBookFileJob.new.perform("k/b.epub", storage: healthy_storage)
    end

    book.reload
    assert_nil book.parse_error
    assert book.cover.attached?
    assert_equal "Doi Ani de Vacanță", book.title
  end

  test "is idempotent — re-running clears missing_since but does not duplicate" do
    storage = stub_storage("k/a.epub", FIXTURES.join("well-tagged.epub"))

    ProcessBookFileJob.new.perform("k/a.epub", storage: storage)
    book = Book.find_by!(object_key: "k/a.epub")
    book.update!(missing_since: 1.hour.ago)

    assert_no_difference "Book.count" do
      ProcessBookFileJob.new.perform("k/a.epub", storage: storage)
    end

    assert_nil book.reload.missing_since
  end

  private

  # Returns a stub that copies the fixture into a fresh tempfile per call.
  # Two reasons we don't return the fixture path directly:
  #   1. ProcessBookFileJob#perform deletes the path in `ensure`. Returning the
  #      fixture path would wipe the on-disk fixture for every subsequent test.
  #   2. The idempotent test calls perform twice, so download must succeed
  #      more than once with the same key.
  #
  # We keep references to the Tempfile objects on @tempfiles so GC doesn't
  # finalize them (and unlink the files) before the job reads them.
  def stub_storage(key, fixture_path)
    @tempfiles ||= []
    tempfiles = @tempfiles
    storage = Object.new
    storage.define_singleton_method(:download) do |k|
      raise ArgumentError, "unexpected key: #{k.inspect}" unless k == key
      tmp = Tempfile.new([ "fixture-", File.extname(fixture_path.to_s) ])
      tmp.binmode
      tmp.write(File.binread(fixture_path.to_s))
      tmp.close
      tempfiles << tmp
      tmp.path
    end
    storage.define_singleton_method(:list) { [] }
    storage
  end
end
