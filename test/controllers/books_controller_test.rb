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
    assert_select ".empty-state"
  end

  test "lists visible books sorted by date descending by default" do
    sign_in_as members(:ana)
    Book.create!(title: "Țara",    format: "epub", object_key: "k1", ingested_at: 1.day.ago)
    Book.create!(title: "Bizanț",  format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path
    titles = css_select(".book-card__title").map(&:text)
    assert_equal [ "Bizanț", "Țara" ], titles
  end

  test "lists visible books sorted by title when requested" do
    sign_in_as members(:ana)
    Book.create!(title: "Țara",    format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Bizanț",  format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(sort: "title")
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

  test "book card author links to catalog filtered by author" do
    sign_in_as members(:ana)
    Book.create!(title: "T", author: "Jules Verne", format: "epub", object_key: "k1", ingested_at: Time.current)

    get root_path
    assert_select ".book-card__author-link[href=?]", "/?q=Jules+Verne", text: "Jules Verne"
  end

  test "book card omits author link when author is blank" do
    sign_in_as members(:ana)
    book = Book.create!(title: "T", format: "epub", object_key: "k1", ingested_at: Time.current)

    get root_path
    assert_select "#book-card-#{book.id} .book-card__author-link", false
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

  test "filter by read status" do
    member = members(:ana)
    sign_in_as member
    b1 = Book.create!(title: "Read",   format: "epub", object_key: "k1", ingested_at: Time.current)
    b2 = Book.create!(title: "Unread", format: "epub", object_key: "k2", ingested_at: Time.current)
    MemberBook.create!(member: member, book: b1, read_at: Time.current)

    get root_path(filter: "read")
    assert_select ".book-card__title", count: 1, text: "Read"

    get root_path(filter: "unread")
    assert_select ".book-card__title", count: 1, text: "Unread"
  end

  test "sidebar shows total book count" do
    member = members(:ana)
    sign_in_as member
    Book.create!(title: "A", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path
    assert_select ".catalog-sidebar__count", text: "2 din 2 cărți"
  end

  test "sidebar count reflects filtered vs total" do
    member = members(:ana)
    sign_in_as member
    Book.create!(title: "A", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(q: "A")
    assert_select ".catalog-sidebar__count", text: "1 din 2 cărți"
  end

  test "sidebar total excludes non-visible books" do
    sign_in_as members(:ana)
    Book.create!(title: "A", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", format: "epub", object_key: "k2", ingested_at: Time.current, missing_since: Time.current)

    get root_path
    assert_select ".catalog-sidebar__count", text: "1 din 1 cărți"
  end

  test "sidebar count reflects reading status filter" do
    member = members(:ana)
    sign_in_as member
    b1 = Book.create!(title: "A", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", format: "epub", object_key: "k2", ingested_at: Time.current)
    MemberBook.create!(member: member, book: b1, read_at: Time.current)

    get root_path(filter: "read")
    assert_select ".catalog-sidebar__count", text: "1 din 2 cărți"
  end

  test "sidebar count total is absolute when search is active" do
    member = members(:ana)
    sign_in_as member
    b1 = Book.create!(title: "A", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", format: "epub", object_key: "k2", ingested_at: Time.current)
    Book.create!(title: "C", format: "epub", object_key: "k3", ingested_at: Time.current)
    MemberBook.create!(member: member, book: b1, read_at: Time.current)

    get root_path(q: "A", filter: "read")
    assert_select ".catalog-sidebar__count", text: "1 din 3 cărți"
  end

  test "invalid filter param falls back to all" do
    sign_in_as members(:ana)
    Book.create!(title: "A", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(filter: "bogus")
    assert_select ".catalog-sidebar__count", text: "2 din 2 cărți"
    assert_select ".catalog-sidebar__filter-item.is-active", count: 1
  end

  test "sidebar shows filter counts" do
    member = members(:ana)
    sign_in_as member
    b1 = Book.create!(title: "A", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", format: "epub", object_key: "k2", ingested_at: Time.current)
    MemberBook.create!(member: member, book: b1, read_at: Time.current)

    get root_path
    counts = css_select(".catalog-sidebar__filter-count").map(&:text)
    assert_equal %w[2 1 1], counts
  end

  test "sorts by date ascending when dir=asc" do
    sign_in_as members(:ana)
    Book.create!(title: "Old", format: "epub", object_key: "k1", ingested_at: 1.day.ago)
    Book.create!(title: "New", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(sort: "date", dir: "asc")
    titles = css_select(".book-card__title").map(&:text)
    assert_equal [ "Old", "New" ], titles
  end

  test "sorts by title descending when dir=desc" do
    sign_in_as members(:ana)
    Book.create!(title: "Țara",   format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Bizanț", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(sort: "title", dir: "desc")
    titles = css_select(".book-card__title").map(&:text)
    assert_equal [ "Țara", "Bizanț" ], titles
  end

  test "sorts by author descending when dir=desc" do
    sign_in_as members(:ana)
    Book.create!(title: "A", author: "Zamfir", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", author: "Andreescu", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(sort: "author", dir: "desc")
    titles = css_select(".book-card__title").map(&:text)
    assert_equal [ "A", "B" ], titles
  end

  test "backwards compat: sort=recent maps to sort=date dir=desc" do
    sign_in_as members(:ana)
    Book.create!(title: "Old", format: "epub", object_key: "k1", ingested_at: 1.day.ago)
    Book.create!(title: "New", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(sort: "recent")
    titles = css_select(".book-card__title").map(&:text)
    assert_equal [ "New", "Old" ], titles
  end

  test "invalid dir param falls back to sort default direction" do
    sign_in_as members(:ana)
    Book.create!(title: "Țara",   format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Bizanț", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(sort: "title", dir: "bogus")
    titles = css_select(".book-card__title").map(&:text)
    assert_equal [ "Bizanț", "Țara" ], titles
  end

  test "invalid sort param falls back to date descending" do
    sign_in_as members(:ana)
    Book.create!(title: "Old", format: "epub", object_key: "k1", ingested_at: 1.day.ago)
    Book.create!(title: "New", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(sort: "bogus")
    titles = css_select(".book-card__title").map(&:text)
    assert_equal [ "New", "Old" ], titles
  end

  test "filter by single language" do
    sign_in_as members(:ana)
    Book.create!(title: "Romanian Book", language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "English Book",  language: "en", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(lang: [ "Romanian" ])
    assert_select ".book-card__title", count: 1, text: "Romanian Book"

    get root_path(lang: [ "English" ])
    assert_select ".book-card__title", count: 1, text: "English Book"
  end

  test "filter by multiple languages" do
    sign_in_as members(:ana)
    Book.create!(title: "A", language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: "en", format: "epub", object_key: "k2", ingested_at: Time.current)
    Book.create!(title: "C", language: "fr", format: "epub", object_key: "k3", ingested_at: Time.current)

    get root_path(lang: %w[Romanian English])
    assert_select ".book-card__title", count: 2
  end

  test "language filter shows all books when no lang param" do
    sign_in_as members(:ana)
    Book.create!(title: "A", language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: "en", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path
    assert_select ".book-card__title", count: 2
  end

  test "invalid lang param falls back to showing all books" do
    sign_in_as members(:ana)
    Book.create!(title: "A", language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: "en", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(lang: [ "bogus" ])
    assert_select ".book-card__title", count: 2
  end

  test "language filter section shows counts per language" do
    sign_in_as members(:ana)
    Book.create!(title: "A", language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: "ro", format: "epub", object_key: "k2", ingested_at: Time.current)
    Book.create!(title: "C", language: "en", format: "epub", object_key: "k3", ingested_at: Time.current)

    get root_path
    assert_select "#lang-filter-all .catalog-sidebar__filter-count", text: "3"
    assert_select "#lang-filter-romanian .catalog-sidebar__filter-count", text: "2"
    assert_select "#lang-filter-english .catalog-sidebar__filter-count", text: "1"
  end

  test "All languages count includes books without a language" do
    sign_in_as members(:ana)
    Book.create!(title: "A", language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: nil, format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path
    assert_select "#lang-filter-all .catalog-sidebar__filter-count", text: "2"
    assert_select "#lang-filter-romanian .catalog-sidebar__filter-count", text: "1"
  end

  test "language filter section is hidden when no books have languages" do
    sign_in_as members(:ana)
    Book.create!(title: "A", format: "epub", object_key: "k1", ingested_at: Time.current)

    get root_path
    assert_select "#lang-filter-all", false
  end

  test "language filter combines with reading status filter" do
    member = members(:ana)
    sign_in_as member
    b1 = Book.create!(title: "Read RO",   language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Unread RO", language: "ro", format: "epub", object_key: "k2", ingested_at: Time.current)
    Book.create!(title: "Read EN",   language: "en", format: "epub", object_key: "k3", ingested_at: Time.current)
    MemberBook.create!(member: member, book: b1, read_at: Time.current)

    get root_path(lang: [ "Romanian" ], filter: "read")
    assert_select ".book-card__title", count: 1, text: "Read RO"
  end

  test "language filter combines with search" do
    sign_in_as members(:ana)
    Book.create!(title: "Amintiri", language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "Amintiri", language: "en", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(lang: [ "Romanian" ], q: "amintiri")
    assert_select ".book-card__title", count: 1
  end

  test "sidebar count total is absolute when language filter is active" do
    sign_in_as members(:ana)
    Book.create!(title: "A", language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: "en", format: "epub", object_key: "k2", ingested_at: Time.current)

    get root_path(lang: [ "Romanian" ])
    assert_select ".catalog-sidebar__count", text: "1 din 2 cărți"
  end

  test "multiple language filters highlight active languages" do
    sign_in_as members(:ana)
    Book.create!(title: "A", language: "ro", format: "epub", object_key: "k1", ingested_at: Time.current)
    Book.create!(title: "B", language: "en", format: "epub", object_key: "k2", ingested_at: Time.current)
    Book.create!(title: "C", language: "fr", format: "epub", object_key: "k3", ingested_at: Time.current)

    get root_path(lang: %w[Romanian English])
    assert_select "#lang-filter-romanian.is-active"
    assert_select "#lang-filter-english.is-active"
    assert_select "#lang-filter-french:not(.is-active)"
    assert_select "#lang-filter-all:not(.is-active)"
  end

  test "toolbar renders sort buttons and direction toggle" do
    sign_in_as members(:ana)
    Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)

    get root_path
    assert_select ".sort-btn", count: 3
    assert_select ".sort-btn.is-active", count: 1
    assert_select ".sort-dir", count: 1
  end

  test "toolbar marks the current sort as active" do
    sign_in_as members(:ana)
    Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)

    get root_path(sort: "title")
    active = css_select(".sort-btn.is-active").map(&:text).map(&:strip)
    assert_equal [ "Titlu" ], active
  end

  test "index stores the catalog path in session" do
    sign_in_as members(:ana)
    get root_path(q: "verne", sort: "title")
    assert_equal "/?q=verne&sort=title", session[:catalog_url]
  end

  test "show breadcrumb links to stored catalog path" do
    sign_in_as members(:ana)
    get root_path(q: "verne")

    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    get book_path(book)
    assert_select "nav.crumbs a[href=?]", "/?q=verne"
  end

  test "show breadcrumb falls back to root when no catalog session" do
    sign_in_as members(:ana)
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    get book_path(book)
    assert_select "nav.crumbs a[href=?]", "/"
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
    assert_select ".book-detail__eyebrow", text: /Jules Verne/
    assert_select ".book-detail__author-link[href=?]", "/?q=Jules+Verne"
    assert_select ".book-detail__desc-body", text: /Un grup de elevi/
    assert_select "dt", false
    assert_no_match(/Editura Test/, response.body)
    assert_no_match(/1888/, response.body)
    assert_no_match(/9781234567890/, response.body)
  end

  test "show renders the Goodreads link when goodreads_url is present" do
    sign_in_as members(:ana)
    book = Book.create!(
      title: "T", format: "epub", object_key: "k", ingested_at: Time.current,
      goodreads_url: "https://www.goodreads.com/book/show/12345"
    )
    get book_path(book)
    assert_select "a.book-detail__goodreads[href=?]", "https://www.goodreads.com/book/show/12345"
  end

  test "show omits the Goodreads link when goodreads_url is blank" do
    sign_in_as members(:ana)
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    get book_path(book)
    assert_select "a.book-detail__goodreads", false
  end

  test "show omits the by-author eyebrow when author is blank" do
    sign_in_as members(:ana)
    book = Book.create!(
      title: "T", format: "epub", object_key: "k", ingested_at: Time.current
    )

    get book_path(book)
    assert_response :success
    assert_select ".book-detail__eyebrow", false
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
    assert_select "#book-rating .journal__rate-btn", count: 3
    assert_select "#book-rating .journal__rate-btn.is-active", count: 0
  end

  test "show marks the current rating as active" do
    sign_in_as members(:ana)
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    MemberBook.create!(member: members(:ana), book: book, rating: :mi_a_placut)
    get book_path(book)
    assert_select "#book-rating .journal__rate-btn.is-active", count: 1
  end

  test "show renders 'mark as read' for an unread book" do
    sign_in_as members(:ana)
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    get book_path(book)
    assert_select "#book-read-toggle button", text: /Marchează ca citită/
  end

  test "show renders 'Citită' when read_at is set" do
    sign_in_as members(:ana)
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current)
    MemberBook.create!(member: members(:ana), book: book, read_at: Time.current)
    get book_path(book)
    assert_select "#book-read-toggle button", text: /Citită/
  end

  test "show renders the Kindle button when the member has a kindle_email" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: true)
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

  test "show renders the unapproved-sender notice when kindle_sender_approved is false" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: false)
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k", ingested_at: Time.current, file_size: 1.megabyte)
    get book_path(book)
    assert_select "#book-kindle #kindle-no-sender"
  end

  test "show renders the oversize notice instead of the button" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: true)
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k",
                        ingested_at: Time.current, file_size: 25.megabytes)
    get book_path(book)
    assert_select "#book-kindle .kindle__notice", text: /depășește 24MB/
  end

  test "show reflects a pending delivery" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: true)
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k",
                        ingested_at: Time.current, file_size: 1.megabyte)
    KindleDelivery.create!(member: member, book: book, status: :pending)
    get book_path(book)
    assert_select "#book-kindle .kindle__status", text: /Se trimite/
  end

  test "show reflects a sent delivery and allows retry" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: true)
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k",
                        ingested_at: Time.current, file_size: 1.megabyte)
    KindleDelivery.create!(member: member, book: book, status: :sent, sent_at: 5.minutes.ago)
    get book_path(book)
    assert_select "#book-kindle .kindle__status", text: /Trimisă acum/
    assert_select "#book-kindle #kindle-send-button"
  end

  test "show reflects a failed delivery" do
    member = members(:ana)
    member.update!(kindle_email: "ana@kindle.com", kindle_sender_approved: true)
    sign_in_as member
    book = Book.create!(title: "T", format: "epub", object_key: "k",
                        ingested_at: Time.current, file_size: 1.megabyte)
    KindleDelivery.create!(member: member, book: book, status: :failed, error: "SMTP timeout")
    get book_path(book)
    assert_select "#book-kindle .kindle__status", text: /Eșuat/
    assert_select "#book-kindle #kindle-send-button"
  end
end
