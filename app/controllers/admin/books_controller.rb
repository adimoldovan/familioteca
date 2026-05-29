module Admin
  class BooksController < BaseController
    FILTER_OPTIONS = %w[needs_metadata needs_goodreads missing_category].freeze

    def index
      @filter = FILTER_OPTIONS.include?(params[:filter]) ? params[:filter] : nil
      scope = case @filter
      when "needs_metadata"   then Book.needs_metadata
      when "needs_goodreads"  then Book.needs_goodreads
      when "missing_category" then Book.without_category
      else Book.all
      end
      @books = scope.order(:sort_title)
    end

    def edit
      @book = Book.includes(:book_categories).find(params[:id])
    end

    def update
      @book = Book.find(params[:id])
      if @book.update(book_params)
        # category_keys is handled outside book_params: sync_categories whitelists
        # the keys itself against Book::CATEGORIES. Only runs on a successful
        # update, so an invalid submit leaves the existing categories untouched.
        @book.sync_categories(params.dig(:book, :category_keys))
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
