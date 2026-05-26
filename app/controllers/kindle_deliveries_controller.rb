class KindleDeliveriesController < ApplicationController
  def create
    book = Book.visible.with_attached_cover.find(params[:book_id])

    if current_member.kindle_email.blank?
      flash.now[:alert] = I18n.t("books.show.kindle.no_kindle_email")
      return render_show_with_status(book, :unprocessable_entity)
    end

    unless current_member.kindle_sender_approved?
      flash.now[:alert] = I18n.t("books.show.kindle.no_sender_approved")
      return render_show_with_status(book, :unprocessable_entity)
    end

    if book.oversize_for_kindle?
      flash.now[:alert] = I18n.t("books.show.kindle.oversize")
      return render_show_with_status(book, :unprocessable_entity)
    end

    delivery = current_member.kindle_deliveries.create!(book: book, status: :pending)
    SendToKindleJob.perform_later(delivery.id)

    respond_to do |format|
      format.turbo_stream do
        @book = book
        @latest_delivery = delivery
        render :create
      end
      format.html { redirect_to book_path(book) }
    end
  end

  private

  def render_show_with_status(book, status)
    @book = book
    @member_book = book.member_book_for(current_member)
    @latest_delivery = KindleDelivery.latest_for(current_member, book)
    render "books/show", status: status
  end
end
