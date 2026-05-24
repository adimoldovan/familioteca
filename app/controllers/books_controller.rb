class BooksController < ApplicationController
  SORT_OPTIONS = %w[recent title author].freeze

  def index
    @query = params[:q].to_s.strip
    @filter = params[:filter].to_s.presence || "all"
    @sort = SORT_OPTIONS.include?(params[:sort]) ? params[:sort] : "recent"

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

    @books = case @sort
    when "title"  then @books.order(:sort_title)
    when "author" then @books.order(Arel.sql("COALESCE(books.author, '') ASC, sort_title ASC"))
    else @books.order(ingested_at: :desc)
    end

    session[:catalog_url] = request.url
  end

  def show
    @book = Book.visible.with_attached_cover.find(params[:id])
    @member_book = @book.member_book_for(current_member)
    @latest_delivery = KindleDelivery.latest_for(current_member, @book)
  end
end
