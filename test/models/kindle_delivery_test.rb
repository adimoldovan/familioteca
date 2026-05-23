require "test_helper"

class KindleDeliveryTest < ActiveSupport::TestCase
  setup do
    @member = members(:ana)
    @book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
  end

  test "default status is pending" do
    kd = KindleDelivery.create!(member: @member, book: @book)
    assert_equal "pending", kd.status
    assert kd.pending?
  end

  test "status enum maps to integers" do
    assert_equal({ "pending" => 0, "sent" => 1, "failed" => 2 }, KindleDelivery.statuses)
  end

  test "transitioning to sent records sent_at" do
    kd = KindleDelivery.create!(member: @member, book: @book)
    freeze_time do
      kd.mark_sent!
      assert_equal "sent", kd.reload.status
      assert_equal Time.current, kd.sent_at
    end
  end

  test "transitioning to failed records the error message" do
    kd = KindleDelivery.create!(member: @member, book: @book)
    kd.mark_failed!("SMTP timeout")
    kd = kd.reload
    assert_equal "failed", kd.status
    assert_equal "SMTP timeout", kd.error
    assert_nil kd.sent_at
  end

  test ".latest_for returns the most recent delivery for the (member, book) pair" do
    a = KindleDelivery.create!(member: @member, book: @book, created_at: 2.days.ago)
    _b = KindleDelivery.create!(member: members(:admin), book: @book)
    c = KindleDelivery.create!(member: @member, book: @book, created_at: 1.minute.ago)
    assert_equal c, KindleDelivery.latest_for(@member, @book)
    refute_equal a, KindleDelivery.latest_for(@member, @book)
  end

  test ".latest_for returns nil when no delivery exists" do
    other_book = Book.create!(title: "B", format: "epub", object_key: "k2", ingested_at: Time.current)
    assert_nil KindleDelivery.latest_for(@member, other_book)
  end

  test "mark_failed! truncates very long error messages" do
    kd = KindleDelivery.create!(member: @member, book: @book)
    kd.mark_failed!("x" * 2_000)
    assert_equal 1_000, kd.reload.error.length
  end
end
