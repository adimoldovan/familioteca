class BooksController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @books = Book.visible.with_attached_cover.search(@query).order(:sort_title)
  end

  def show
    @book = Book.visible.with_attached_cover.find(params[:id])
    @member_book = @book.member_book_for(current_member)
    @latest_delivery = KindleDelivery.latest_for(current_member, @book)
  end
end
