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
    assert_redirected_to edit_admin_book_path(@book)
    @book.reload
    assert_equal "Nouă", @book.title
    assert_equal "Autor", @book.author
  end

  test "admin edits goodreads_url" do
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: {
      book: { goodreads_url: "https://www.goodreads.com/book/show/12345" }
    }
    assert_redirected_to edit_admin_book_path(@book)
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

  test "invalid update keeps the filter in the re-rendered form" do
    sign_in_as members(:admin)
    patch admin_book_path(@book, filter: "needs_goodreads"), params: { book: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "form[action=?]", admin_book_path(@book, filter: "needs_goodreads")
  end

  test "admin edit form includes category checkboxes" do
    sign_in_as members(:admin)
    get edit_admin_book_path(@book)
    assert_select "input[type=checkbox][name='book[category_keys][]'][value=fiction]"
    assert_select "input[type=checkbox][name='book[category_keys][]'][value=non_fiction]"
    assert_select "input[type=checkbox][name='book[category_keys][]'][value=biography]"
    assert_select "input[type=checkbox][name='book[category_keys][]'][value=essays]"
  end

  test "admin assigns categories on update" do
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: {
      book: { title: "Nouă", category_keys: %w[fiction biography] }
    }
    assert_redirected_to edit_admin_book_path(@book)
    assert_equal %w[biography fiction], @book.reload.category_keys.sort
  end

  test "admin clears categories when none are checked" do
    @book.sync_categories(%w[fiction])
    sign_in_as members(:admin)
    patch admin_book_path(@book), params: { book: { title: "Nouă" } }
    assert_redirected_to edit_admin_book_path(@book)
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

  test "edit form carries the filter through cancel and submit" do
    sign_in_as members(:admin)
    get edit_admin_book_path(@book, filter: "needs_goodreads")
    assert_response :success
    assert_select "a.btn[href=?]", admin_books_path(filter: "needs_goodreads") # cancel
    assert_select "form[action=?]", admin_book_path(@book, filter: "needs_goodreads")
  end

  test "save stays on the edit form keeping the filter" do
    sign_in_as members(:admin)
    patch admin_book_path(@book, filter: "needs_goodreads"), params: { book: { title: "Nouă" } }
    assert_redirected_to edit_admin_book_path(@book, filter: "needs_goodreads")
  end

  test "prev and next link to neighbours in the filtered, sorted list" do
    a = Book.create!(title: "Aaa", format: "epub", object_key: "ka", ingested_at: Time.current)
    b = Book.create!(title: "Bbb", format: "epub", object_key: "kb", ingested_at: Time.current)
    c = Book.create!(title: "Ccc", format: "epub", object_key: "kc", ingested_at: Time.current)
    sign_in_as members(:admin)

    get edit_admin_book_path(b)
    assert_select "a.btn[href=?]", edit_admin_book_path(a) # previous
    assert_select "a.btn[href=?]", edit_admin_book_path(c) # next
  end

  test "neighbours are scoped to the active filter, not the whole table" do
    # @book ("Old") has goodreads_url, so it is not in needs_goodreads.
    @book.update!(goodreads_url: "https://www.goodreads.com/book/show/1")
    a = Book.create!(title: "Aaa", format: "epub", object_key: "ka", ingested_at: Time.current)
    b = Book.create!(title: "Bbb", format: "epub", object_key: "kb", ingested_at: Time.current)
    c = Book.create!(title: "Ccc", format: "epub", object_key: "kc", ingested_at: Time.current)
    sign_in_as members(:admin)

    get edit_admin_book_path(b, filter: "needs_goodreads")
    assert_select "a.btn[href=?]", edit_admin_book_path(a, filter: "needs_goodreads") # previous
    assert_select "a.btn[href=?]", edit_admin_book_path(c, filter: "needs_goodreads") # next
    # @book is excluded by the filter, so it never appears as a neighbour.
    assert_select "a.btn[href=?]", edit_admin_book_path(@book, filter: "needs_goodreads"), false
  end

  test "save and open next ignores a next_book_id outside the active filter" do
    @book.update!(goodreads_url: "https://www.goodreads.com/book/show/1") # not in needs_goodreads
    a = Book.create!(title: "Aaa", format: "epub", object_key: "ka", ingested_at: Time.current)
    sign_in_as members(:admin)

    patch admin_book_path(a, filter: "needs_goodreads"), params: {
      book: { title: "Aaa" }, save_action: "next", next_book_id: @book.id
    }
    # @book is outside the filter, so it falls back to the current book.
    assert_redirected_to edit_admin_book_path(a, filter: "needs_goodreads")
  end

  test "next is hidden at the end of the list" do
    last = Book.create!(title: "Zzz", format: "epub", object_key: "kz", ingested_at: Time.current)
    sign_in_as members(:admin)
    get edit_admin_book_path(last)
    assert_select "nav.book-edit-nav a.btn", 1 # only previous is shown, next is hidden
    assert_select "a.btn[href=?]", edit_admin_book_path(last), false
    assert_select "button[name=save_action]", false
  end

  test "save and open next jumps to the next book in the filter" do
    a = Book.create!(title: "Aaa", format: "epub", object_key: "ka", ingested_at: Time.current)
    b = Book.create!(title: "Bbb", format: "epub", object_key: "kb", ingested_at: Time.current)
    sign_in_as members(:admin)

    patch admin_book_path(a), params: {
      book: { title: "Aaa" }, save_action: "next", next_book_id: b.id
    }
    assert_redirected_to edit_admin_book_path(b)
  end

  test "save and open next button is present when there is a next book" do
    Book.create!(title: "Zzz", format: "epub", object_key: "kz", ingested_at: Time.current)
    sign_in_as members(:admin)

    get edit_admin_book_path(@book) # "Old" sorts before "Zzz", so a next exists
    assert_select "button[name=save_action][value=next][data-controller=hotkey][aria-keyshortcuts=s]" \
                  "[title=?]", "Salvează și deschide următoarea (S)"
    assert_select "input[type=hidden][name=next_book_id]"
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
