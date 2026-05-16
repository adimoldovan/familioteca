require_relative "../../config/environment"
require "gepub"
require "fileutils"
require "stringio"
require "zlib"

# Generates the EPUB fixtures used by parser and job tests. Called from
# test_helper (before Rails forks parallel test workers) or directly during
# development:
#
#   ruby -Itest test/helpers/ebook_fixtures.rb
#
# Idempotent: skips files that already exist.
module EbookFixtures
  DIR = Rails.root.join("test/fixtures/files/ebooks")

  def self.png_chunk(type, data)
    crc = Zlib.crc32(type + data)
    [ data.bytesize ].pack("N") + type + data + [ crc ].pack("N")
  end

  # Minimal valid 1×1 transparent RGBA PNG. Built so image libraries
  # (MiniMagick, vips, etc.) won't reject the bytes if they touch them.
  COVER_PNG = (
    "\x89PNG\r\n\x1a\n".b +
    png_chunk("IHDR", [ 1, 1, 8, 6, 0, 0, 0 ].pack("NNCCCCC")) +
    png_chunk("IDAT", Zlib::Deflate.deflate("\x00\x00\x00\x00\x00".b)) +
    png_chunk("IEND", "".b)
  ).freeze

  def self.generate_all
    FileUtils.mkdir_p(DIR)

    write("well-tagged.epub") do |book|
      book.identifier = "isbn:9781234567890"
      book.title      = "Doi Ani de Vacanță"
      book.creator    = "Jules Verne"
      book.language   = "ro"
      book.publisher  = "Editura Test"
      book.date       = "1888-01-01T00:00:00Z"
      book.description = "Un grup de elevi naufragiază pe o insulă pustie."
      book.add_item("cover.png", content: StringIO.new(COVER_PNG)).cover_image
      book.ordered { book.add_item("ch1.xhtml", content: StringIO.new("<html><body><h1>Cap. 1</h1></body></html>")) }
    end

    write("no-cover.epub") do |book|
      book.identifier = "id:no-cover"
      book.title      = "Fără Copertă"
      book.creator    = "Autor Anonim"
      book.language   = "ro"
      book.ordered { book.add_item("ch1.xhtml", content: StringIO.new("<html><body>x</body></html>")) }
    end

    write("no-metadata.epub") do |book|
      # Only the title is set (gepub requires it for a valid EPUB). Author,
      # language, description, publisher, ISBN are intentionally omitted.
      book.identifier = "id:bare"
      book.title      = "Untitled"
      book.ordered { book.add_item("ch1.xhtml", content: StringIO.new("<html><body>x</body></html>")) }
    end

    write("romanian-diacritics.epub") do |book|
      book.identifier = "id:ro"
      book.title      = "Bizanț, Bizanț"
      book.creator    = "Lucian Boia"
      book.language   = "ro"
      book.description = "Despre mănăstiri, țăranii și pădurile României."
      book.add_item("cover.png", content: StringIO.new(COVER_PNG)).cover_image
      book.ordered { book.add_item("ch1.xhtml", content: StringIO.new("<html><body>x</body></html>")) }
    end

    corrupt = DIR.join("corrupt.epub")
    File.binwrite(corrupt, "not actually an epub") unless File.exist?(corrupt)
  end

  def self.write(name)
    target = DIR.join(name)
    return if File.exist?(target)
    book = GEPUB::Book.new
    yield book
    book.generate_epub(target.to_s)
  end
end

if __FILE__ == $PROGRAM_NAME
  EbookFixtures.generate_all
  puts "Fixtures generated in #{EbookFixtures::DIR}"
end
