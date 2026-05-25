module Admin
  class BooksController < BaseController
    FILTER_OPTIONS = %w[needs_metadata needs_goodreads].freeze

    def index
      @filter = FILTER_OPTIONS.include?(params[:filter]) ? params[:filter] : nil
      scope = case @filter
      when "needs_metadata"  then Book.needs_metadata
      when "needs_goodreads" then Book.needs_goodreads
      else Book.all
      end
      @books = scope.order(:sort_title)
    end

    def edit
      @book = Book.find(params[:id])
    end

    def update
      @book = Book.find(params[:id])
      if @book.update(book_params)
        redirect_to admin_books_path, notice: t("admin.books.update.success")
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

    def destroy
      @book = Book.find(params[:id])
      @book.destroy!
      redirect_to admin_books_path, notice: t("admin.books.destroy.success")
    end

    private

    def book_params
      params.require(:book).permit(:title, :author, :language, :publisher,
                                   :published_year, :isbn, :goodreads_url, :description)
    end
  end
end
