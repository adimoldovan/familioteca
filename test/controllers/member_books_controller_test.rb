require "test_helper"

class MemberBooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
  end

  test "auth is required" do
    patch book_member_book_path(@book), params: { rating: "mi_a_placut" }
    assert_redirected_to sign_in_path
  end

  test "setting a rating creates the row" do
    sign_in_as members(:ana)
    assert_difference "MemberBook.count", 1 do
      patch book_member_book_path(@book), params: { rating: "mi_a_placut" }
    end
    mb = MemberBook.find_by!(member: members(:ana), book: @book)
    assert_equal "mi_a_placut", mb.rating
  end

  test "submitting the same rating again clears it (toggle)" do
    sign_in_as members(:ana)
    patch book_member_book_path(@book), params: { rating: "mi_a_placut" }
    patch book_member_book_path(@book), params: { rating: "mi_a_placut" }
    assert_nil MemberBook.find_by!(member: members(:ana), book: @book).rating
  end

  test "submitting a different rating overwrites the current one" do
    sign_in_as members(:ana)
    patch book_member_book_path(@book), params: { rating: "asa_si_asa" }
    patch book_member_book_path(@book), params: { rating: "mi_a_placut" }
    assert_equal "mi_a_placut", MemberBook.find_by!(member: members(:ana), book: @book).rating
  end

  test "setting a rating automatically marks the book as read" do
    sign_in_as members(:ana)
    freeze_time do
      patch book_member_book_path(@book), params: { rating: "mi_a_placut" }
      mb = MemberBook.find_by!(member: members(:ana), book: @book)
      assert_equal Time.current, mb.read_at
    end
  end

  test "toggling a rating off does not clear read status" do
    sign_in_as members(:ana)
    patch book_member_book_path(@book), params: { rating: "mi_a_placut" }
    patch book_member_book_path(@book), params: { rating: "mi_a_placut" }
    mb = MemberBook.find_by!(member: members(:ana), book: @book)
    assert_nil mb.rating
    assert_not_nil mb.read_at
  end

  test "rating does not overwrite an existing read_at" do
    sign_in_as members(:ana)
    earlier = 1.day.ago
    MemberBook.create!(member: members(:ana), book: @book, read_at: earlier)
    patch book_member_book_path(@book), params: { rating: "asa_si_asa" }
    assert_in_delta earlier, MemberBook.find_by!(member: members(:ana), book: @book).read_at, 1
  end

  test "explicit read=false overrides auto-read from rating" do
    sign_in_as members(:ana)
    patch book_member_book_path(@book), params: { rating: "mi_a_placut", read: "false" }
    mb = MemberBook.find_by!(member: members(:ana), book: @book)
    assert_equal "mi_a_placut", mb.rating
    assert_nil mb.read_at
  end

  test "submitting read=true sets read_at" do
    sign_in_as members(:ana)
    freeze_time do
      patch book_member_book_path(@book), params: { read: "true" }
      assert_equal Time.current, MemberBook.find_by!(member: members(:ana), book: @book).read_at
    end
  end

  test "rating and read can be set together in one request" do
    sign_in_as members(:ana)
    freeze_time do
      patch book_member_book_path(@book), params: { rating: "asa_si_asa", read: "true" }
      mb = MemberBook.find_by!(member: members(:ana), book: @book)
      assert_equal "asa_si_asa", mb.rating
      assert_equal Time.current, mb.read_at
    end
  end

  test "submitting read=false clears read_at" do
    sign_in_as members(:ana)
    patch book_member_book_path(@book), params: { read: "true" }
    patch book_member_book_path(@book), params: { read: "false" }
    assert_nil MemberBook.find_by!(member: members(:ana), book: @book).read_at
  end

  test "unknown rating value is rejected with 422" do
    sign_in_as members(:ana)
    patch book_member_book_path(@book), params: { rating: "bogus" }
    assert_response :unprocessable_entity
  end

  test "missing book returns 404" do
    sign_in_as members(:ana)
    @book.update!(missing_since: Time.current)
    patch book_member_book_path(@book), params: { rating: "mi_a_placut" }
    assert_response :not_found
  end

  test "responds with turbo-stream when requested" do
    sign_in_as members(:ana)
    patch book_member_book_path(@book),
      params: { rating: "mi_a_placut" },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match %r{<turbo-stream action="replace" target="book-rating">}, @response.body
    assert_match %r{<turbo-stream action="replace" target="book-read-toggle">}, @response.body
  end

  test "request with neither rating nor read is rejected with 422" do
    sign_in_as members(:ana)
    assert_no_difference "MemberBook.count" do
      patch book_member_book_path(@book)
    end
    assert_response :unprocessable_entity
  end

  test "writes are scoped to current_member (cannot affect another member's row)" do
    other = MemberBook.create!(member: members(:admin), book: @book, rating: :mi_a_placut)
    sign_in_as members(:ana)
    patch book_member_book_path(@book), params: { rating: "nu_mi_a_placut" }
    assert_response :redirect
    assert_equal "mi_a_placut", other.reload.rating
    assert_equal "nu_mi_a_placut", MemberBook.find_by!(member: members(:ana), book: @book).rating
  end
end
