class BooksController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @books = Book.visible.with_attached_cover.search(@query).order(:sort_title)
  end
end
