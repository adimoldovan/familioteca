require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated visitor is redirected to /sign_in" do
    get root_path
    assert_redirected_to sign_in_path
  end

  test "signed-in member sees the empty state when no books exist" do
    sign_in_as members(:ana)
    get root_path
    assert_response :success
    assert_select "h1", "Bibliotecă"
    assert_select ".empty-state"
  end

  test "lists visible books sorted by sort_title" do
    sign_in_as members(:ana)
    Book.create!(title: "Țara",    format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Bizanț",  format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path
    titles = css_select(".book-card__title").map(&:text)
    assert_equal [ "Bizanț", "Țara" ], titles
  end

  test "excludes books with missing_since set" do
    sign_in_as members(:ana)
    Book.create!(title: "Visible", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Hidden",  format: "epub", object_key: "k2", ingested_at: Time.current,
                  missing_since: Time.current)

    get root_path
    assert_select ".book-card__title", count: 1, text: "Visible"
  end

  test "excludes books with parse_error set" do
    sign_in_as members(:ana)
    Book.create!(title: "Visible", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Broken",  format: "epub", object_key: "k2", ingested_at: Time.current,
                  parse_error: "metadata extraction failed")

    get root_path
    assert_select ".book-card__title", count: 1, text: "Visible"
  end
end
