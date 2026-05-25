class BooksController < ApplicationController
  SORT_OPTIONS = %w[date title author].freeze
  DIR_OPTIONS = %w[asc desc].freeze
  SORT_DEFAULTS = { "date" => "desc", "title" => "asc", "author" => "asc" }.freeze

  def index
    @query = params[:q].to_s.strip
    @filter = params[:filter].to_s.presence || "all"

    raw_sort = params[:sort].to_s
    @sort = if raw_sort == "recent"
      "date"
    elsif SORT_OPTIONS.include?(raw_sort)
      raw_sort
    else
      "date"
    end

    @dir = DIR_OPTIONS.include?(params[:dir]) ? params[:dir] : SORT_DEFAULTS[@sort]

    base = Book.visible.with_attached_cover.search(@query)
    read_scope = current_member.member_books.where.not(read_at: nil).select(:book_id)

    @counts = {
      all: base.count,
      unread: base.where.not(id: read_scope).count,
      read: base.where(id: read_scope).count
    }

    @books = case @filter
    when "read"  then base.where(id: read_scope)
    when "unread" then base.where.not(id: read_scope)
    else base
    end

    direction = @dir == "desc" ? :desc : :asc

    @books = case @sort
    when "title"  then @books.order(sort_title: direction)
    when "author"
      dir_sql = @dir.upcase
      @books.order(Arel.sql("COALESCE(books.author, '') #{dir_sql}, sort_title #{dir_sql}"))
    else @books.order(ingested_at: direction)
    end

    session[:catalog_url] = request.fullpath if request.format.html?
  end

  def show
    @book = Book.visible.with_attached_cover.find(params[:id])
    @member_book = @book.member_book_for(current_member)
    @latest_delivery = KindleDelivery.latest_for(current_member, @book)
    url = session[:catalog_url]
    @catalog_url = url&.match?(%r{\A/[^/]}) ? url : root_path
  end
end
