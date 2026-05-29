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

  test "admin edit form includes category checkboxes" do
    sign_in_as members(:admin)
    get edit_admin_book_path(@book)
    assert_select "input[type=checkbox][name='book[category_keys][]'][value=fiction]"
    assert_select "input[type=checkbox][name='book[category_keys][]'][value=non_fiction]"
    assert_select "input[type=checkbox][name='book[category_keys][]'][value=biography]"
  end

  test "admin assigns categories on update" do
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: {
      book: { title: "Nouă", category_keys: %w[fiction biography] }
    }
    assert_redirected_to admin_books_path
    assert_equal %w[biography fiction], @book.reload.category_keys.sort
  end

  test "admin clears categories when none are checked" do
    @book.sync_categories(%w[fiction])
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: { book: { title: "Nouă" } }
    assert_redirected_to admin_books_path
    assert_empty @book.reload.category_keys
  end

  test "invalid metadata update leaves the existing categories unchanged" do
    @book.sync_categories(%w[fiction])
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: { book: { title: "", category_keys: %w[biography] } }
    assert_response :unprocessable_entity
    assert_equal %w[fiction], @book.reload.category_keys
  end

  test "failed update re-renders the form with the submitted categories checked" do
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: { book: { title: "", category_keys: %w[biography] } }
    assert_response :unprocessable_entity
    assert_select "input[name='book[category_keys][]'][value=biography][checked=checked]"
    assert_select "input[name='book[category_keys][]'][value=fiction]:not([checked])"
  end

  test "failed update with all categories cleared re-renders with none checked" do
    @book.sync_categories(%w[fiction])
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: { book: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "input[name='book[category_keys][]'][checked=checked]", false
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
