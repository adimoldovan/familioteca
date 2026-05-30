require "test_helper"

class Admin::BooksRescanTest < ActionDispatch::IntegrationTest
  setup do
    @book = Book.create!(title: "Rescannable", format: "epub", object_key: "rescan.epub", ingested_at: Time.current)
  end

  test "admin enqueues ProcessBookFileJob and redirects to edit with queued notice" do
    sign_in_as members(:admin)
    assert_enqueued_with(job: ProcessBookFileJob, args: [ @book.object_key ]) do
      post rescan_admin_book_path(@book)
    end
    assert_redirected_to edit_admin_book_path(@book)
    assert_equal I18n.t("admin.books.rescan.queued"), flash[:notice]
  end

  test "rescan preserves the active filter in the redirect" do
    sign_in_as members(:admin)
    post rescan_admin_book_path(@book, filter: "needs_metadata")
    assert_redirected_to edit_admin_book_path(@book, filter: "needs_metadata")
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
