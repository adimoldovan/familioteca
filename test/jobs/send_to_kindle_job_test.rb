require "test_helper"
require "tempfile"

class SendToKindleJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @member = members(:ana)
    @member.update!(kindle_email: "ana@kindle.com")
    @book = Book.create!(
      title: "T", format: "epub", object_key: "verne/x.epub",
      ingested_at: Time.current, file_size: 1.megabyte
    )
    @delivery = KindleDelivery.create!(member: @member, book: @book)
  end

  test "downloads, mails, and marks the delivery sent" do
    storage = stub_storage("verne/x.epub", "epub bytes")

    assert_emails 1 do
      SendToKindleJob.new.perform(@delivery.id, storage: storage)
    end

    @delivery.reload
    assert_equal "sent", @delivery.status
    refute_nil @delivery.sent_at
  end

  test "marks failed on mailer error and re-raises so Solid Queue retries" do
    storage = stub_storage("verne/x.epub", "epub bytes")

    # Simulate a failure by clearing the kindle_email AFTER the delivery row
    # was created, so the mailer's `to:` ends up nil.
    @member.update_columns(kindle_email: nil)

    assert_raises(ArgumentError) do
      SendToKindleJob.new.perform(@delivery.id, storage: storage)
    end

    @delivery.reload
    assert_equal "failed", @delivery.status
    refute_empty @delivery.error
  end

  test "transient errors leave the delivery pending so retry_on can retry" do
    storage = Object.new
    storage.define_singleton_method(:download) do |_key|
      raise Seahorse::Client::NetworkingError.new(StandardError.new("net"))
    end

    assert_raises(Seahorse::Client::NetworkingError) do
      SendToKindleJob.new.perform(@delivery.id, storage: storage)
    end

    @delivery.reload
    assert_equal "pending", @delivery.status
    assert_nil @delivery.error
  end

  test "cleans up the temp file even on failure" do
    storage = Object.new
    path_seen = nil
    storage.define_singleton_method(:download) do |_key|
      tmp = Tempfile.new([ "fixture-", ".epub" ])
      tmp.write("epub bytes")
      tmp.close
      path_seen = tmp.path
      tmp.path
    end
    @member.update_columns(kindle_email: nil) # forces ArgumentError

    assert_raises(ArgumentError) do
      SendToKindleJob.new.perform(@delivery.id, storage: storage)
    end

    refute File.exist?(path_seen), "tempfile should have been cleaned up"
  end

  private

  def stub_storage(key, body)
    storage = Object.new
    storage.define_singleton_method(:download) do |k|
      raise "unexpected key #{k.inspect}" unless k == key
      tmp = Tempfile.new([ "fixture-", ".epub" ])
      tmp.binmode
      tmp.write(body)
      tmp.close
      tmp.path
    end
    storage
  end
end
