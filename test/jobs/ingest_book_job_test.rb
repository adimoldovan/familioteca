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

  private

  def build_storage(keys)
    storage = Object.new
    storage.define_singleton_method(:list) { keys }
    storage
  end
end
