module Admin
  class BooksController < BaseController
    FILTER_OPTIONS = %w[needs_metadata needs_goodreads missing_category].freeze

    def index
      @filter = current_filter
      @books = filtered_books(@filter)
    end

    def edit
      @book = Book.includes(:book_categories).find(params[:id])
      @filter = current_filter
      assign_neighbours
    end

    def update
      @book = Book.find(params[:id])
      @filter = current_filter
      if @book.update(book_params)
        # category_keys is handled outside book_params: sync_categories whitelists
        # the keys itself against Book::CATEGORIES. Only runs on a successful
        # update, so an invalid submit leaves the existing categories untouched.
        @book.sync_categories(params.dig(:book, :category_keys))
        redirect_to after_save_path, notice: t("admin.books.update.success")
      else
        assign_neighbours
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

    def current_filter
      FILTER_OPTIONS.include?(params[:filter]) ? params[:filter] : nil
    end

    def filtered_books(filter)
      scope = case filter
      when "needs_metadata"   then Book.needs_metadata
      when "needs_goodreads"  then Book.needs_goodreads
      when "missing_category" then Book.without_category
      else Book.all
      end
      scope.order(:sort_title)
    end

    # Neighbours within the current filter, captured at page-load while the book
    # is still in the list. "Save and open next" carries @next_book_id forward so
    # the queue keeps flowing even when saving drops the book out of the filter.
    def assign_neighbours
      ids = filtered_books(@filter).pluck(:id)
      index = ids.index(@book.id)
      return unless index

      @prev_book_id = ids[index - 1] if index.positive?
      @next_book_id = ids[index + 1] if index < ids.length - 1
    end

    def after_save_path
      next_id = params[:next_book_id].to_i.nonzero?
      jump_to_next = params[:save_action] == "next" && next_id &&
                     filtered_books(@filter).exists?(next_id)
      target = jump_to_next ? next_id : @book
      edit_admin_book_path(target, filter: @filter)
    end

    def book_params
      params.require(:book).permit(:title, :author, :language, :publisher,
                                   :published_year, :isbn, :goodreads_url, :description)
    end
  end
end
