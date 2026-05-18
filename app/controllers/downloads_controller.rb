class DownloadsController < ApplicationController
  def show
    book = Book.visible.find(params[:id])
    redirect_to BookStorage.default.presigned_url(book.object_key, expires_in: 5.minutes.to_i),
                allow_other_host: true
  end
end
