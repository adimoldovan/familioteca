class BooksController < ApplicationController
  SORT_OPTIONS = %w[date title author].freeze
  DIR_OPTIONS = %w[asc desc].freeze
  SORT_DEFAULTS = { "date" => "desc", "title" => "asc", "author" => "asc" }.freeze

  def index
    @query = params[:q].to_s.strip
    @filter = params[:filter].to_s.presence || "all"

    normalized = params[:sort].to_s.then { |s| s == "recent" ? "date" : s }
    @sort = SORT_OPTIONS.include?(normalized) ? normalized : "date"

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

    direction = @dir.to_sym

    @books = case @sort
    when "title"  then @books.order(sort_title: direction)
    when "author"
      coalesce = Arel::Nodes::NamedFunction.new("COALESCE", [ Book.arel_table[:author], Arel::Nodes.build_quoted("") ])
      order_node = direction == :asc ? coalesce.asc : coalesce.desc
      @books.order(order_node, sort_title: direction)
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
