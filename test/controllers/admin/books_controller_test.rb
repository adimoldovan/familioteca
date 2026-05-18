require "test_helper"

class Admin::BooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ok      = Book.create!(title: "Ok",      format: "epub", object_key: "k1", ingested_at: Time.current)
    @missing = Book.create!(title: "Missing", format: "epub", object_key: "k2", ingested_at: Time.current,
                            missing_since: 1.hour.ago)
    @broken  = Book.create!(title: "broken.epub", format: "epub", object_key: "k3", ingested_at: Time.current,
                            parse_error: "boom")
  end

  test "non-admin gets 404" do
    sign_in_as members(:ana)
    get admin_books_path
    assert_response :not_found
  end

  test "admin sees all books by default" do
    sign_in_as members(:admin)
    get admin_books_path
    assert_response :success
    assert_select "table tbody tr", 3
  end

  test "admin can filter to needs-metadata" do
    sign_in_as members(:admin)
    get admin_books_path(filter: "needs_metadata")
    assert_response :success
    assert_select "table tbody tr", 1
    assert_select "td", text: "broken.epub"
  end
end
