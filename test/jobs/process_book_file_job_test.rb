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
    assert_equal "image/png", book.cover.blob.content_type
    assert_equal "#{book.id}-cover.png", book.cover.blob.filename.to_s
    refute_nil book.ingested_at
    assert_nil book.parse_error
  end

  test "attaches JPEG covers with the right content_type and extension" do
    storage = stub_storage("test/jpeg.epub", FIXTURES.join("jpeg-cover.epub"))

    ProcessBookFileJob.new.perform("test/jpeg.epub", storage: storage)

    book = Book.find_by!(object_key: "test/jpeg.epub")
    assert book.cover.attached?
    assert_equal "image/jpeg", book.cover.blob.content_type
    assert_equal "#{book.id}-cover.jpg", book.cover.blob.filename.to_s
  end

  test "downgrades unsupported cover content_types to octet-stream + .bin" do
    book = Book.create!(object_key: "test/k", title: "t", format: "epub", ingested_at: Time.current)
    result = {
      cover_io: StringIO.new("anything"),
      cover_content_type: "image/svg+xml"
    }

    ProcessBookFileJob.new.send(:attach_cover, book, result)

    assert_equal "application/octet-stream", book.cover.blob.content_type
    assert_equal "#{book.id}-cover.bin", book.cover.blob.filename.to_s
  end

  test "falls back to octet-stream + .bin when cover_content_type is missing" do
    book = Book.create!(object_key: "test/k2", title: "t", format: "epub", ingested_at: Time.current)
    result = { cover_io: StringIO.new("anything"), cover_content_type: nil }

    ProcessBookFileJob.new.send(:attach_cover, book, result)

    assert_equal "application/octet-stream", book.cover.blob.content_type
    assert_equal "#{book.id}-cover.bin", book.cover.blob.filename.to_s
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

  test "does not retry programming errors" do
    with_default_storage(->(_) { raise NoMethodError, "boom" }) do
      perform_enqueued_jobs do
        assert_raises(NoMethodError) do
          ProcessBookFileJob.perform_later("any/key.epub")
        end
      end
    end
  end

  test "retries transient S3 networking errors" do
    attempts = 0
    downloader = ->(_) {
      attempts += 1
      raise Seahorse::Client::NetworkingError.new(IOError.new("connection reset"))
    }

    with_default_storage(downloader) do
      perform_enqueued_jobs do
        assert_raises(Seahorse::Client::NetworkingError) do
          ProcessBookFileJob.perform_later("any/key.epub")
        end
      end
    end
    assert_equal 3, attempts
  end

  test "does not retry permanent S3 errors like NoSuchKey" do
    attempts = 0
    downloader = ->(_) {
      attempts += 1
      raise Aws::S3::Errors::NoSuchKey.new(nil, "object missing")
    }

    with_default_storage(downloader) do
      perform_enqueued_jobs do
        assert_raises(Aws::S3::Errors::NoSuchKey) do
          ProcessBookFileJob.perform_later("missing/key.epub")
        end
      end
    end
    assert_equal 1, attempts
  end

  test "re-running replaces the cover when the source EPUB cover changes" do
    png_storage = stub_storage("k/c.epub", FIXTURES.join("well-tagged.epub"))
    ProcessBookFileJob.new.perform("k/c.epub", storage: png_storage)
    book = Book.find_by!(object_key: "k/c.epub")
    assert_equal "image/png", book.cover.blob.content_type
    original_blob_id = book.cover.blob.id

    jpeg_storage = stub_storage("k/c.epub", FIXTURES.join("jpeg-cover.epub"))
    ProcessBookFileJob.new.perform("k/c.epub", storage: jpeg_storage)

    book.reload
    assert book.cover.attached?
    assert_equal "image/jpeg", book.cover.blob.content_type
    refute_equal original_blob_id, book.cover.blob.id
  end

  test "re-running purges the cover when the new EPUB has none" do
    with_cover = stub_storage("k/d.epub", FIXTURES.join("well-tagged.epub"))
    ProcessBookFileJob.new.perform("k/d.epub", storage: with_cover)
    book = Book.find_by!(object_key: "k/d.epub")
    assert book.cover.attached?

    without_cover = stub_storage("k/d.epub", FIXTURES.join("no-cover.epub"))
    ProcessBookFileJob.new.perform("k/d.epub", storage: without_cover)

    refute book.reload.cover.attached?
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

  def with_default_storage(downloader)
    fake = Object.new
    fake.define_singleton_method(:download) { |key| downloader.call(key) }
    original = BookStorage.method(:default)
    BookStorage.define_singleton_method(:default) { fake }
    begin
      yield
    ensure
      BookStorage.define_singleton_method(:default, original)
    end
  end

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
