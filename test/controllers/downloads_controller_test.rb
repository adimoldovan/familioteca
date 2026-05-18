require "test_helper"

class DownloadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @book = Book.create!(title: "T", format: "epub", object_key: "verne/x.epub",
                         ingested_at: Time.current)
  end

  test "redirects to a presigned URL containing the object key" do
    sign_in_as members(:ana)
    get download_book_path(@book)
    assert_response :redirect
    assert_match "verne/x.epub", response.location
  end

  test "auth required" do
    get download_book_path(@book)
    assert_redirected_to sign_in_path
  end

  test "missing book returns 404" do
    sign_in_as members(:ana)

    @book.update!(missing_since: Time.current)
    get download_book_path(@book)
    assert_response :not_found

    @book.update!(missing_since: nil, parse_error: "bad parse")
    get download_book_path(@book)
    assert_response :not_found

    get download_book_path(id: 0)
    assert_response :not_found
  end
end
