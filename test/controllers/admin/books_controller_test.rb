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

  test "admin can filter to needs-goodreads" do
    sign_in_as members(:admin)
    @ok.update!(goodreads_url: "https://www.goodreads.com/book/show/1")
    no_url = Book.create!(title: "No URL", format: "epub", object_key: "k4", ingested_at: Time.current)
    get admin_books_path(filter: "needs_goodreads")
    assert_response :success
    titles = css_select("td").map(&:text)
    assert_includes titles, no_url.title
    refute_includes titles, @ok.title
    refute_includes titles, @broken.title
    refute_includes titles, @missing.title
  end

  test "admin can delete a book" do
    sign_in_as members(:admin)
    assert_difference("Book.count", -1) do
      delete admin_book_path(@ok)
    end
    assert_redirected_to admin_books_path
    assert_equal I18n.t("admin.books.destroy.success"), flash[:notice]
  end

  test "non-admin cannot delete a book" do
    sign_in_as members(:ana)
    assert_no_difference("Book.count") do
      delete admin_book_path(@ok)
    end
    assert_response :not_found
  end

  test "deleting a book also destroys associated member_books" do
    sign_in_as members(:admin)
    member = members(:ana)
    @ok.member_books.create!(member: member)
    assert_difference [ "Book.count", "MemberBook.count" ], -1 do
      delete admin_book_path(@ok)
    end
    assert_redirected_to admin_books_path
  end
end
