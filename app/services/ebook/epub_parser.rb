require "gepub"

module Ebook
  module EpubParser
    class ParseError < StandardError; end

    SORT_NAME_SUFFIXES = /\A(Jr|Sr|[IVX]+|Inc|LLC|Ltd|Co)\.?\z/i

    def self.call(path)
      book = GEPUB::Book.parse(path)

      title = first_string(book.title) || File.basename(path, ".*")
      author = unsort_author_name(first_string(book.creator))

      isbn = extract_isbn(book)

      attrs = {
        title: title,
        author: author,
        language: first_string(book.language),
        publisher: first_string(book.publisher),
        published_year: extract_year(book.date),
        isbn: isbn,
        goodreads_url: extract_goodreads_url(book),
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

    GOODREADS_URL_PATTERN = %r{\Ahttps://www\.goodreads\.com/book/show/\S+\z}

    def self.extract_goodreads_url(book)
      book.identifier_list.each do |id|
        str = first_string(id)
        return str if str&.match?(GOODREADS_URL_PATTERN)
      end

      meta = book.metadata.oldstyle_meta.find { |m| m["name"] == "goodreads-url" }
      url = meta && first_string(meta["content"])
      url if url&.match?(GOODREADS_URL_PATTERN)
    end

    # "Bocai, Iulian" → "Iulian Bocai"; leaves normal names untouched.
    def self.unsort_author_name(name)
      return name unless name
      match = name.match(/\A\s*([^,]+?)\s*,\s*([^,]+?)\s*\z/)
      return name unless match && !match[2].match?(SORT_NAME_SUFFIXES)
      "#{match[2]} #{match[1]}"
    end

    def self.extract_cover(book)
      item = find_cover_item(book)
      return {} unless item
      { cover_io: StringIO.new(item.content), cover_content_type: first_string(item.media_type) }
    rescue StandardError
      {}
    end

    # EPUB 3 marks the cover with properties="cover-image" on the manifest
    # item. EPUB 2 declares it via <meta name="cover" content="<item-id>"/>
    # in metadata and the manifest item itself carries no marker.
    def self.find_cover_item(book)
      epub3 = book.items.values.find { |i| i.properties&.include?("cover-image") }
      return epub3 if epub3

      meta = book.metadata.oldstyle_meta.find { |m| m["name"] == "cover" }
      cover_id = meta && meta["content"]
      cover_id.present? ? book.items[cover_id] : nil
    end
  end
end
