class BooksController < ApplicationController
  SORT_OPTIONS = %w[date title author].freeze
  DIR_OPTIONS = %w[asc desc].freeze
  FILTER_OPTIONS = %w[all unread read].freeze
  SORT_DEFAULTS = { "date" => "desc", "title" => "asc", "author" => "asc" }.freeze

  def index
    @query = params[:q].to_s.strip
    @filter = FILTER_OPTIONS.include?(params[:filter]) ? params[:filter] : "all"

    @available_languages = Book.available_languages
    @langs = Array(params[:lang]).select { |l| @available_languages.include?(l) }

    @categories = Array(params[:category]).select { |c| Book::CATEGORIES.include?(c) }

    normalized = params[:sort].to_s.then { |s| s == "recent" ? "date" : s }
    @sort = SORT_OPTIONS.include?(normalized) ? normalized : "date"

    @dir = DIR_OPTIONS.include?(params[:dir]) ? params[:dir] : SORT_DEFAULTS[@sort]

    read_scope = current_member.member_books.where.not(read_at: nil).select(:book_id)
    searched = Book.visible.search(@query)

    # Reading-status counts reflect the active language + category selections, but
    # not the reading-status filter itself, so all three options stay visible.
    base = searched.by_language(@langs).by_category(@categories)
    @counts = {
      all: base.count,
      unread: base.where.not(id: read_scope).count,
      read: base.where(id: read_scope).count
    }

    @total_count = @query.blank? && @langs.empty? && @categories.empty? ? @counts[:all] : Book.visible.count

    # Each facet's counts reflect the OTHER active filters (search, reading status,
    # and the sibling facet), but not its own selection, so the user sees how many
    # books each option would add.
    reading_filtered = filter_by_reading_status(searched, read_scope)

    language_base = reading_filtered.by_category(@categories)
    @language_all_count = language_base.count
    @language_counts = language_base
      .where(language: @available_languages)
      .group(:language)
      .count

    category_base = reading_filtered.by_language(@langs)
    @category_all_count = category_base.count
    @category_counts = BookCategory
      .where(book_id: category_base.select(:id))
      .group(:category)
      .count

    rendered = base.with_attached_cover
    @books = case @filter
    when "read"  then rendered.where(id: read_scope)
    when "unread" then rendered.where.not(id: read_scope)
    else rendered
    end

    direction = @dir.to_sym

    @books = case @sort
    when "title"  then @books.order(sort_title: direction)
    when "author"
      coalesce = Arel::Nodes::NamedFunction.new("COALESCE", [ Book.arel_table[:author], Arel::Nodes.build_quoted("") ])
      order_node = direction == :asc ? coalesce.asc : coalesce.desc
      @books.order(order_node, sort_title: direction)
    else @books.order(ingested_at: direction)
    end

    session[:catalog_url] = request.fullpath if store_catalog_url?
  end

  def show
    @book = Book.visible.with_attached_cover.includes(:book_categories).find(params[:id])
    @member_book = @book.member_book_for(current_member)
    @latest_delivery = KindleDelivery.latest_for(current_member, @book)
    url = session[:catalog_url]
    @catalog_url = url&.match?(%r{\A/[^/]}) ? url : root_path
  end

  private

  # Restrict a scope to the active reading-status filter (read/unread), or leave
  # it unchanged for "all".
  def filter_by_reading_status(scope, read_scope)
    case @filter
    when "read"   then scope.where(id: read_scope)
    when "unread" then scope.where.not(id: read_scope)
    else scope
    end
  end

  # Turbo prefetches links on hover (e.g. a book's author link), which fires a
  # GET to #index. Recording that as the catalog URL would corrupt the book-page
  # breadcrumb, so skip prefetch requests and only store real HTML navigations.
  def store_catalog_url?
    request.format.html? && !request.headers["X-Sec-Purpose"].to_s.start_with?("prefetch")
  end
end
