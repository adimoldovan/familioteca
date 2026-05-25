require "test_helper"

class Admin::BooksEditTest < ActionDispatch::IntegrationTest
  setup do
    @book = Book.create!(title: "Old", format: "epub", object_key: "k", ingested_at: Time.current)
  end

  test "admin edits book metadata" do
    sign_in_as members(:admin)
    get edit_admin_book_path(@book)
    assert_response :success
    assert_select "form input[name='book[title]']"

    patch admin_book_path(@book), params: {
      book: { title: "Nouă", author: "Autor", description: "Despre ceva." }
    }
    assert_redirected_to admin_books_path
    @book.reload
    assert_equal "Nouă", @book.title
    assert_equal "Autor", @book.author
  end

  test "admin edits goodreads_url" do
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: {
      book: { goodreads_url: "https://www.goodreads.com/book/show/12345" }
    }
    assert_redirected_to admin_books_path
    assert_equal "https://www.goodreads.com/book/show/12345", @book.reload.goodreads_url
  end

  test "admin edit form includes goodreads_url field" do
    sign_in_as members(:admin)
    get edit_admin_book_path(@book)
    assert_select "form input[name='book[goodreads_url]']"
  end

  test "invalid goodreads_url re-renders form with 422" do
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: {
      book: { goodreads_url: "https://evil.example.com/book/show/1" }
    }
    assert_response :unprocessable_entity
    assert_select "div.error-summary"
    assert_nil @book.reload.goodreads_url
  end

  test "invalid update re-renders form with 422" do
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: { book: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "form input[name='book[title]']"
    assert_select "div.error-summary"
    assert_equal "Old", @book.reload.title
  end

  test "non-admin gets 404 on edit" do
    sign_in_as members(:ana)
    get edit_admin_book_path(@book)
    assert_response :not_found
  end

  test "non-admin gets 404 on update" do
    sign_in_as members(:ana)
    patch admin_book_path(@book), params: { book: { title: "Hack" } }
    assert_response :not_found
    assert_equal "Old", @book.reload.title
  end
end
