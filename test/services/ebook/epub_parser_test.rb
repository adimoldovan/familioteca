require "test_helper"

module Ebook
  class EpubParserTest < ActiveSupport::TestCase
    FIXTURES = Rails.root.join("test/fixtures/files/ebooks").freeze

    test "parses well-tagged EPUB" do
      result = EpubParser.call(FIXTURES.join("well-tagged.epub").to_s)
      attrs = result[:attributes]
      assert_equal "Doi Ani de Vacanță", attrs[:title]
      assert_equal "Jules Verne",         attrs[:author]
      assert_equal "ro",                  attrs[:language]
      assert_equal "Editura Test",        attrs[:publisher]
      assert_equal 1888,                  attrs[:published_year]
      assert_match(/elevi naufragiază/, attrs[:description])
      assert_equal "9781234567890",       attrs[:isbn]
      refute_nil result[:cover_io]
      assert_equal "image/png", result[:cover_content_type]
    end

    test "returns the real cover media_type for JPEG covers" do
      result = EpubParser.call(FIXTURES.join("jpeg-cover.epub").to_s)
      refute_nil result[:cover_io]
      assert_equal "image/jpeg", result[:cover_content_type]
    end

    test "parses EPUB without cover" do
      result = EpubParser.call(FIXTURES.join("no-cover.epub").to_s)
      assert_equal "Fără Copertă", result[:attributes][:title]
      assert_nil result[:cover_io]
      assert_nil result[:cover_content_type]
    end

    test "parses EPUB with only the bare-minimum metadata" do
      result = EpubParser.call(FIXTURES.join("no-metadata.epub").to_s)
      attrs = result[:attributes]
      assert_equal "Untitled", attrs[:title]
      assert_nil attrs[:author]
      assert_nil attrs[:description]
      assert_nil attrs[:publisher]
    end

    test "preserves Romanian diacritics" do
      result = EpubParser.call(FIXTURES.join("romanian-diacritics.epub").to_s)
      assert_equal "Bizanț, Bizanț", result[:attributes][:title]
      assert_equal "Lucian Boia",    result[:attributes][:author]
      assert_match(/mănăstiri/, result[:attributes][:description])
    end

    test "raises on corrupt file" do
      assert_raises(Ebook::EpubParser::ParseError) do
        EpubParser.call(FIXTURES.join("corrupt.epub").to_s)
      end
    end

    test "raises on missing file" do
      assert_raises(Ebook::EpubParser::ParseError) do
        EpubParser.call(FIXTURES.join("does-not-exist.epub").to_s)
      end
    end
  end
end
