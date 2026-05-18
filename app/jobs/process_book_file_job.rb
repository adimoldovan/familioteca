class ProcessBookFileJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(object_key, storage: BookStorage.default)
    path = storage.download(object_key)
    result = Ebook::Parser.call(path, object_key: object_key)
    attrs = result[:attributes]

    book = Book.find_or_initialize_by(object_key: object_key)
    book.assign_attributes(
      title:          attrs[:title] || File.basename(object_key, ".*"),
      author:         attrs[:author],
      language:       attrs[:language],
      publisher:      attrs[:publisher],
      published_year: attrs[:published_year],
      isbn:           attrs[:isbn],
      description:    attrs[:description],
      format:         result[:format],
      file_size:      File.size(path),
      ingested_at:    Time.current,
      missing_since:  nil,
      parse_error:    result[:parse_error]
    )
    book.save!

    if result[:cover_io] && !book.cover.attached?
      book.cover.attach(
        io: result[:cover_io],
        filename: "#{book.id}-cover.png",
        content_type: "image/png"
      )
    end
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
