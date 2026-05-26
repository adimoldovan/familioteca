require "test_helper"

class KindleDeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @book = Book.create!(
      title: "T", format: "epub", object_key: "k",
      ingested_at: Time.current, file_size: 1.megabyte
    )
  end

  test "auth is required" do
    post book_kindle_deliveries_path(@book)
    assert_redirected_to sign_in_path
  end

  test "creates a pending delivery and enqueues the job" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: true)
    sign_in_as member

    assert_difference "KindleDelivery.count", 1 do
      assert_enqueued_with(job: SendToKindleJob) do
        post book_kindle_deliveries_path(@book),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end
    end

    delivery = KindleDelivery.order(:created_at).last
    assert_equal "pending", delivery.status
    assert_equal member, delivery.member
    assert_equal @book, delivery.book

    assert_response :success
    assert_match "turbo-stream", @response.body
  end

  test "422 when the member has no kindle_email" do
    member = members(:ana)
    member.update!(kindle_email: nil)
    sign_in_as member

    assert_no_difference "KindleDelivery.count" do
      post book_kindle_deliveries_path(@book)
    end
    assert_response :unprocessable_entity
    assert_no_match(/translation missing/i, @response.body)
    assert_includes @response.body, I18n.t("books.show.kindle.no_kindle_email")
  end

  test "422 when the member has not approved the sender" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: false)
    sign_in_as member

    assert_no_difference "KindleDelivery.count" do
      post book_kindle_deliveries_path(@book)
    end
    assert_response :unprocessable_entity
    assert_includes @response.body, I18n.t("books.show.kindle.no_sender_approved")
  end

  test "422 when the book is oversize" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: true)
    sign_in_as member
    @book.update!(file_size: 25.megabytes)

    assert_no_difference "KindleDelivery.count" do
      post book_kindle_deliveries_path(@book)
    end
    assert_response :unprocessable_entity
  end

  test "404 when the book is missing" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: true)
    sign_in_as member
    @book.update!(missing_since: Time.current)

    post book_kindle_deliveries_path(@book)
    assert_response :not_found
  end
end
