module Ebook
  module FilenameParser
    SEPARATOR = /\s+-\s+/.freeze

    def self.call(path)
      basename = File.basename(path, ".*")
      parts = basename.split(SEPARATOR, 2)

      attrs =
        if parts.length == 2
          { author: parts[0].strip, title: parts[1].strip }
        else
          { title: basename.strip }
        end

      { attributes: attrs, cover_io: nil }
    end
  end
end
