require "test_helper"
require "tempfile"
require "turbo/broadcastable/test_helper"

class SendToKindleJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  include Turbo::Broadcastable::TestHelper

  setup do
    @member = members(:ana)
    @member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: true)
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

  test "broadcasts a sent-state kindle button to the (book, member) channel on success" do
    storage = stub_storage("verne/x.epub", "epub bytes")

    streams = capture_turbo_stream_broadcasts([ @book, @member, :kindle_status ]) do
      SendToKindleJob.new.perform(@delivery.id, storage: storage)
    end

    assert_equal 1, streams.count
    assert_equal "book-kindle", streams.first["target"]
    assert_match(/Trimisă/, streams.first.to_s)
  end

  test "broadcasts a failed-state kindle button on non-transient error" do
    # Point the storage at a non-existent file so File.binread inside the
    # mailer raises Errno::ENOENT — a non-transient error that hits the
    # rescue branch with kindle_email still set.
    storage = Object.new
    storage.define_singleton_method(:download) { |_key| "/tmp/familioteca-does-not-exist-#{SecureRandom.hex}.epub" }

    streams = capture_turbo_stream_broadcasts([ @book, @member, :kindle_status ]) do
      assert_raises(Errno::ENOENT) do
        SendToKindleJob.new.perform(@delivery.id, storage: storage)
      end
    end

    assert_equal 1, streams.count
    assert_match(/Eșuat/, streams.first.to_s)
  end

  test "mark_delivery_failed broadcasts so retry_on exhaustion drives the UI" do
    # retry_on's exhaustion callback invokes job.mark_delivery_failed(error)
    # on the job instance that just failed its last attempt — so @delivery_id
    # is set. Simulate that call shape directly.
    job = SendToKindleJob.new
    job.instance_variable_set(:@delivery_id, @delivery.id)

    streams = capture_turbo_stream_broadcasts([ @book, @member, :kindle_status ]) do
      job.mark_delivery_failed(Seahorse::Client::NetworkingError.new(StandardError.new("net")))
    end

    @delivery.reload
    assert_equal "failed", @delivery.status
    assert_equal 1, streams.count
    assert_match(/Eșuat/, streams.first.to_s)
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
