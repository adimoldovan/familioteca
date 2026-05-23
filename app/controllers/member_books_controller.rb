class MemberBooksController < ApplicationController
  VALID_RATINGS = MemberBook.ratings.keys.freeze

  def update
    return head :unprocessable_entity unless params.key?(:rating) || params.key?(:read)
    return head :unprocessable_entity if params.key?(:rating) && !VALID_RATINGS.include?(params[:rating])

    book = Book.visible.find(params[:book_id])
    mb = upsert_member_book(book)

    respond_to do |format|
      format.turbo_stream do
        @book = book
        @member_book = mb
        render :update
      end
      format.html { redirect_to book_path(book) }
    end
  end

  private

  def upsert_member_book(book)
    attempts = 0
    begin
      mb = current_member.member_books.find_or_initialize_by(book: book)
      mb.rating = toggle_rating(mb.rating, params[:rating]) if params.key?(:rating)
      mb.read_at = ActiveModel::Type::Boolean.new.cast(params[:read]) ? Time.current : nil if params.key?(:read)
      mb.save!
      mb
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      retry if attempts < 2
      raise
    end
  end

  def toggle_rating(current, submitted)
    current == submitted ? nil : submitted
  end
end
