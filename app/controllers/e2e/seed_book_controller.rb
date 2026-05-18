module E2e
  class SeedBookController < BaseController
    def create
      book = Book.create!(
        title: params[:title] || "Seeded Book",
        author: params[:author],
        description: params[:description],
        format: params[:format].presence_in(Book::FORMATS) || "epub",
        object_key: params[:object_key] || "seed/#{SecureRandom.hex(4)}.epub",
        ingested_at: Time.current
      )
      render json: { id: book.id, title: book.title }
    end
  end
end
