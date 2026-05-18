require "gepub"

module Ebook
  module EpubParser
    class ParseError < StandardError; end

    def self.call(path)
      book = GEPUB::Book.parse(path)

      title = first_string(book.title) || File.basename(path, ".*")
      author = first_string(book.creator)

      isbn = extract_isbn(book)

      attrs = {
        title: title,
        author: author,
        language: first_string(book.language),
        publisher: first_string(book.publisher),
        published_year: extract_year(book.date),
        isbn: isbn,
        description: first_string(book.description)
      }.compact

      { attributes: attrs }.merge(extract_cover(book))
    rescue ParseError
      raise
    rescue StandardError => e
      raise ParseError, "Could not parse EPUB: #{e.message}"
    end

    def self.first_string(value)
      value&.to_s&.strip&.presence
    end

    def self.extract_year(value)
      str = first_string(value)
      return nil if str.nil?
      match = str.match(/\d{4}/)
      match ? match[0].to_i : nil
    end

    def self.extract_isbn(book)
      book.identifier_list.each do |id|
        str = first_string(id)
        next if str.nil?
        match = str.match(/\A(?:urn:)?isbn:(.+)\z/i)
        return match[1] if match
      end
      nil
    end

    def self.extract_cover(book)
      item = book.items.values.find { |i| i.properties&.include?("cover-image") }
      return {} unless item
      { cover_io: StringIO.new(item.content), cover_content_type: first_string(item.media_type) }
    rescue StandardError
      {}
    end
  end
end
