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

    get root_path(q: "   ")
    assert_select ".book-card__title", count: 2
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

  test "search filters books by diacritic-insensitive match" do
    sign_in_as members(:ana)
    Book.create!(title: "Bizanț", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Cluj",   format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(q: "bizant")
    assert_select ".book-card__title", count: 1, text: "Bizanț"
  end

  test "search renders a no-results message when nothing matches" do
    sign_in_as members(:ana)
    Book.create!(title: "Bizanț", format: "epub", object_key: "k1", ingested_at: Time.current)

    get root_path(q: "xxnomatchxx")
    assert_select ".empty-state", text: /xxnomatchxx/
  end

  test "search preserves the query in the input field" do
    sign_in_as members(:ana)
    get root_path(q: "verne")
    assert_select "input[type=search][value=?]", "verne"
  end

  test "search escapes HTML in the query in the no-results message" do
    sign_in_as members(:ana)
    get root_path(q: "<script>alert(1)</script>")
    assert_select ".empty-state__body"
    assert_no_match(/<script>/, response.body)
  end

  test "shows a book's full metadata" do
    sign_in_as members(:ana)
    book = Book.create!(
      title: "Doi Ani de Vacanță",
      author: "Jules Verne",
      publisher: "Editura Test",
      published_year: 1888,
      language: "ro",
      isbn: "9781234567890",
      description: "Un grup de elevi naufragiază pe o insulă.",
      format: "epub",
      object_key: "k",
      ingested_at: Time.current
    )

    get book_path(book)
    assert_response :success
    assert_select "h1", text: /Doi Ani de Vacanță/
    assert_select ".book-show__by-author", text: "de Jules Verne"
    assert_select ".book-show__pill", count: 2
    assert_select ".book-show__pill", text: "EPUB"
    assert_select ".book-show__pill", text: "ro"
    assert_select ".book-show__description", text: /Un grup de elevi/
    assert_select "dt", false
    assert_no_match(/Editura Test/, response.body)
    assert_no_match(/1888/, response.body)
    assert_no_match(/9781234567890/, response.body)
  end

  test "show omits the language pill and by-author line when those fields are blank" do
    sign_in_as members(:ana)
    book = Book.create!(
      title: "T", format: "epub", object_key: "k", ingested_at: Time.current
    )

    get book_path(book)
    assert_response :success
    assert_select ".book-show__pill", count: 1
    assert_select ".book-show__pill", text: "EPUB"
    assert_select ".book-show__by-author", false
  end

  test "show is protected by auth" do
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    get book_path(book)
    assert_redirected_to sign_in_path
  end

  test "show returns 404 for a non-visible book" do
    sign_in_as members(:ana)
    book = Book.create!(title: "Hidden", format: "epub", object_key: "k",
                        ingested_at: Time.current, missing_since: Time.current)
    get book_path(book)
    assert_response :not_found
  end

  test "show renders the rating buttons for a signed-in member" do
    sign_in_as members(:ana)
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    get book_path(book)
    assert_select "#book-rating .rating__option", count: 3
    assert_select "#book-rating .rating__option--active", count: 0
  end

  test "show marks the current rating as active" do
    sign_in_as members(:ana)
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    MemberBook.create!(member: members(:ana), book: book, rating: :mi_a_placut)
    get book_path(book)
    assert_select "#book-rating .rating__option--active", count: 1
    assert_select ".rating__option--active", text: /Mi-a plăcut/
  end

  test "show renders 'mark as read' for an unread book" do
    sign_in_as members(:ana)
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    get book_path(book)
    assert_select "#book-read-toggle button", text: /Marchează ca citită/
  end

  test "show renders 'mark as unread' when read_at is set" do
    sign_in_as members(:ana)
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    MemberBook.create!(member: members(:ana), book: book, read_at: Time.current)
    get book_path(book)
    assert_select "#book-read-toggle button", text: /Marchează ca necitită/
  end

  test "show renders the Kindle button when the member has a kindle_email" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com")
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k",
                        ingested_at: Time.current, file_size: 1.megabyte)
    get book_path(book)
    assert_select "#book-kindle #kindle-send-button"
  end

  test "show renders the missing-kindle-email notice" do
    member = members(:ana)
    member.update!(kindle_email: nil)
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    get book_path(book)
    assert_select "#book-kindle .kindle__notice", text: /Adaugă un Email Kindle/
  end

  test "show renders the oversize notice instead of the button" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com")
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k",
                        ingested_at: Time.current, file_size: 25.megabytes)
    get book_path(book)
    assert_select "#book-kindle .kindle__notice", text: /depășește 24MB/
  end

  test "show reflects a pending delivery" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com")
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k",
                        ingested_at: Time.current, file_size: 1.megabyte)
    KindleDelivery.create!(member: member, book: book, status: :pending)
    get book_path(book)
    assert_select "#book-kindle .kindle__status", text: /Se trimite/
  end

  test "show reflects a sent delivery and allows retry" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com")
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k",
                        ingested_at: Time.current, file_size: 1.megabyte)
    KindleDelivery.create!(member: member, book: book, status: :sent, sent_at: 5.minutes.ago)
    get book_path(book)
    assert_select "#book-kindle .kindle__status", text: /Trimisă/
    assert_select "#book-kindle #kindle-send-button"
  end

  test "show reflects a failed delivery" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com")
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k",
                        ingested_at: Time.current, file_size: 1.megabyte)
    KindleDelivery.create!(member: member, book: book, status: :failed, error: "SMTP timeout")
    get book_path(book)
    assert_select "#book-kindle .kindle__status", text: /Eșuat/
    assert_select "#book-kindle #kindle-send-button"
  end
end
