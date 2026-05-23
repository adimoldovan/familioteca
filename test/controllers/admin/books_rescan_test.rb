require "test_helper"

class Admin::BooksRescanTest < ActionDispatch::IntegrationTest
  setup do
    @book = Book.create!(title: "Rescannable", format: "epub", object_key: "rescan.epub", ingested_at: Time.current)
  end

  test "admin enqueues ProcessBookFileJob and gets turbo stream" do
    sign_in_as members(:admin)
    assert_enqueued_with(job: ProcessBookFileJob, args: [ @book.object_key ]) do
      post rescan_admin_book_path(@book), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='#{dom_id(@book, :actions)}']" do
      assert_select ".scan-button__status", text: I18n.t("admin.books.index.rescanning")
    end
  end

  test "admin html fallback redirects with queued notice" do
    sign_in_as members(:admin)
    assert_enqueued_with(job: ProcessBookFileJob, args: [ @book.object_key ]) do
      post rescan_admin_book_path(@book)
    end
    assert_redirected_to admin_books_path
    assert_equal I18n.t("admin.books.rescan.queued"), flash[:notice]
  end

  test "non-admin gets 404" do
    sign_in_as members(:ana)
    post rescan_admin_book_path(@book)
    assert_response :not_found
  end

  test "unauthenticated visitor is redirected to sign_in" do
    post rescan_admin_book_path(@book)
    assert_redirected_to sign_in_path
  end
end
