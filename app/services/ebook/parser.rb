module Ebook
  module Parser
    FORMAT_BY_EXTENSION = {
      ".epub" => "epub",
      ".mobi" => "mobi",
      ".pdf"  => "pdf"
    }.freeze

    # `path` is the file on disk to parse. `object_key` is the original
    # storage key used as the source of filename hints — the tempfile path
    # passed in `path` typically has a randomized name, so we prefer the
    # original key whenever the parser falls back to filename inference.
    def self.call(path, object_key: nil)
      ext = File.extname(path).downcase
      # Unknown extensions normalize to "pdf" so they pass the Book FORMATS
      # inclusion validation. Revisit if we add a dedicated "other" format.
      format = FORMAT_BY_EXTENSION[ext] || "pdf"
      fallback_name = object_key || path

      if ext == ".epub"
        begin
          result = EpubParser.call(path)
          return result.merge(format: format)
        rescue EpubParser::ParseError => e
          fallback = FilenameParser.call(fallback_name)
          return fallback.merge(format: format, parse_error: e.message)
        end
      end

      FilenameParser.call(fallback_name).merge(format: format)
    end
  end
end
