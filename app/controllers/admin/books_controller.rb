module Admin
  class BooksController < BaseController
    def index
      scope = case params[:filter]
      when "needs_metadata" then Book.needs_metadata
      else Book.all
      end
      @books = scope.order(:sort_title)
      @filter = params[:filter]
    end

    def edit
      @book = Book.find(params[:id])
    end

    def update
      @book = Book.find(params[:id])
      if @book.update(book_params)
        redirect_to admin_books_path, notice: I18n.t("admin.books.update.success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def rescan
      @book = Book.find(params[:id])
      ProcessBookFileJob.perform_later(@book.object_key)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_books_path, notice: t("admin.books.rescan.queued") }
      end
    end

    private

    def book_params
      params.require(:book).permit(:title, :author, :language, :publisher,
                                   :published_year, :isbn, :description)
    end
  end
end
