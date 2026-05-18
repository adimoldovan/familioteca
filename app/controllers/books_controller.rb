class BooksController < ApplicationController
  def index
    @books = Book.visible.with_attached_cover.order(:sort_title)
  end
end
