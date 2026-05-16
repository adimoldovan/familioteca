require "test_helper"

module Ebook
  class FilenameParserTest < ActiveSupport::TestCase
    test "parses 'Author - Title.epub'" do
      result = FilenameParser.call("/tmp/Mihai Eminescu - Luceafărul.epub")
      assert_equal "Luceafărul", result[:attributes][:title]
      assert_equal "Mihai Eminescu", result[:attributes][:author]
      assert_nil result[:cover_io]
    end

    test "parses 'Title.epub' (no author hint)" do
      result = FilenameParser.call("/tmp/Doi Ani de Vacanță.epub")
      assert_equal "Doi Ani de Vacanță", result[:attributes][:title]
      assert_nil result[:attributes][:author]
    end

    test "strips extension regardless of case" do
      result = FilenameParser.call("/tmp/Some Book.MOBI")
      assert_equal "Some Book", result[:attributes][:title]
    end

    test "preserves Romanian diacritics" do
      result = FilenameParser.call("/tmp/Țara - Lumea Țăranilor.epub")
      assert_equal "Țara", result[:attributes][:author]
      assert_equal "Lumea Țăranilor", result[:attributes][:title]
    end

    test "handles a bare filename without directory" do
      result = FilenameParser.call("Book.epub")
      assert_equal "Book", result[:attributes][:title]
    end

    test "splits only on the first ' - ' separator" do
      result = FilenameParser.call("/tmp/Umberto Eco - Il Nome - della Rosa.epub")
      assert_equal "Umberto Eco", result[:attributes][:author]
      assert_equal "Il Nome - della Rosa", result[:attributes][:title]
    end
  end
end
