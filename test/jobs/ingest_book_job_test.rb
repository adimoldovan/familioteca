require "test_helper"

class IngestBookJobTest < ActiveJob::TestCase
  test "enqueues ProcessBookFileJob for each new key" do
    storage = build_storage(%w[a.epub b.epub])

    assert_enqueued_jobs 2, only: ProcessBookFileJob do
      IngestBookJob.new.perform(storage: storage)
    end
  end

  test "does not re-enqueue keys already in Book table" do
    Book.create!(title: "A", format: "epub", object_key: "a.epub", ingested_at: Time.current)
    storage = build_storage(%w[a.epub b.epub])

    assert_enqueued_jobs 1, only: ProcessBookFileJob do
      IngestBookJob.new.perform(storage: storage)
    end
  end

  test "marks keys absent from the bucket as missing" do
    book = Book.create!(title: "Gone", format: "epub", object_key: "gone.epub", ingested_at: Time.current)
    storage = build_storage([])

    freeze_time do
      IngestBookJob.new.perform(storage: storage)
      assert_equal Time.current.to_i, book.reload.missing_since.to_i
    end
  end

  test "does not overwrite missing_since on a book that is still missing" do
    original = 3.days.ago
    book = Book.create!(title: "Still gone", format: "epub", object_key: "still_gone.epub",
                        ingested_at: 1.week.ago, missing_since: original)
    storage = build_storage([])

    IngestBookJob.new.perform(storage: storage)

    assert_equal original.to_i, book.reload.missing_since.to_i
  end

  test "clears missing_since when a previously missing key reappears in the bucket" do
    book = Book.create!(title: "Back", format: "epub", object_key: "back.epub",
                        ingested_at: 1.week.ago, missing_since: 1.day.ago)
    storage = build_storage([ "back.epub" ])

    assert_no_enqueued_jobs only: ProcessBookFileJob do
      IngestBookJob.new.perform(storage: storage)
    end
    assert_nil book.reload.missing_since
  end

  test "records the storage last-modified time on present books" do
    modified = Time.utc(2026, 5, 1, 12, 0, 0)
    book = Book.create!(title: "A", format: "epub", object_key: "a.epub", ingested_at: Time.current)
    storage = build_storage("a.epub" => modified)

    IngestBookJob.new.perform(storage: storage)

    assert_equal modified.to_i, book.reload.file_modified_at.to_i
  end

  test "recording the file time does not bump updated_at" do
    book = Book.create!(title: "A", format: "epub", object_key: "a.epub", ingested_at: Time.current)
    storage = build_storage("a.epub" => Time.utc(2026, 5, 1, 12, 0, 0))

    # Advance the clock so a stray save! would produce a visibly newer
    # updated_at; update_all must leave it untouched.
    travel 1.hour do
      IngestBookJob.new.perform(storage: storage)
    end

    assert_equal book.updated_at.to_i, book.reload.updated_at.to_i
  end

  test "does not rewrite books whose file time already matches" do
    modified = Time.utc(2026, 5, 1, 12, 0, 0)
    Book.create!(title: "A", format: "epub", object_key: "a.epub", ingested_at: Time.current,
                 file_modified_at: modified)
    storage = build_storage("a.epub" => modified)

    assert_no_queries_match(/update .*file_modified_at/i) do
      IngestBookJob.new.perform(storage: storage)
    end
    assert_equal modified.to_i, Book.find_by!(object_key: "a.epub").file_modified_at.to_i
  end

  test "a file modified after the last DB write is flagged for rescan" do
    book = Book.create!(title: "A", format: "epub", object_key: "a.epub", ingested_at: 1.week.ago)
    storage = build_storage("a.epub" => 1.minute.from_now)

    IngestBookJob.new.perform(storage: storage)

    assert_includes Book.needs_rescan, book.reload
  end

  private

  # Accepts a list of keys (each gets a default modified time) or a
  # key => last_modified hash, and yields BookStorage::Entry structs from #list.
  def build_storage(keys_or_times)
    entries = Array(keys_or_times).map do |key, time|
      BookStorage::Entry.new(key, time || Time.current)
    end
    storage = Object.new
    storage.define_singleton_method(:list) { entries }
    storage
  end
end
