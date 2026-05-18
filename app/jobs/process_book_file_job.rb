class ProcessBookFileJob < ApplicationJob
  queue_as :default

  # Only retry transient infrastructure failures. Programming errors
  # (NoMethodError, ArgumentError, etc.) and permanent S3 errors
  # (NoSuchKey, AccessDenied) should fail fast and surface in logs rather
  # than burn three queue slots before giving up.
  retry_on Seahorse::Client::NetworkingError,
           Aws::S3::Errors::RequestTimeout,
           Aws::S3::Errors::ServiceUnavailable,
           Aws::S3::Errors::SlowDown,
           Aws::S3::Errors::InternalError,
           wait: :polynomially_longer,
           attempts: 3

  # SVG is intentionally excluded — Active Storage can serve allowed image
  # types inline, and inline SVG can execute embedded scripts. Anything not
  # in this table is downgraded to application/octet-stream + .bin so the
  # blob is served as a download rather than rendered.
  COVER_EXTENSION_BY_CONTENT_TYPE = {
    "image/png"  => ".png",
    "image/jpeg" => ".jpg",
    "image/gif"  => ".gif",
    "image/webp" => ".webp"
  }.freeze

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

    attach_cover(book, result) if result[:cover_io] && !book.cover.attached?
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  private

  def attach_cover(book, result)
    declared  = result[:cover_content_type].presence
    extension = COVER_EXTENSION_BY_CONTENT_TYPE[declared]
    if extension
      content_type = declared
    else
      content_type = "application/octet-stream"
      extension    = ".bin"
    end
    # identify: false so Active Storage trusts the type we chose. Otherwise
    # Marcel would re-sniff the bytes and could promote a malicious cover
    # (e.g. SVG mislabelled as image/png by the EPUB) back to an
    # executable type that gets served inline.
    book.cover.attach(
      io: result[:cover_io],
      filename: "#{book.id}-cover#{extension}",
      content_type: content_type,
      identify: false
    )
  end
end
