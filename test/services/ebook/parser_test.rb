require "test_helper"

module Ebook
  class ParserTest < ActiveSupport::TestCase
    FIXTURES = Rails.root.join("test/fixtures/files/ebooks").freeze

    test "dispatches .epub to EpubParser" do
      result = Parser.call(FIXTURES.join("well-tagged.epub").to_s)
      assert_equal "Doi Ani de Vacanță", result[:attributes][:title]
      assert_equal "epub", result[:format]
    end

    test "passes EPUB word_count through" do
      result = Parser.call(FIXTURES.join("word-count.epub").to_s)
      assert_equal 15, result[:word_count]
    end

    test "dispatches .mobi to FilenameParser" do
      result = Parser.call("/tmp/Jules Verne - Insula misterioasă.mobi")
      assert_equal "Insula misterioasă", result[:attributes][:title]
      assert_equal "Jules Verne", result[:attributes][:author]
      assert_equal "mobi", result[:format]
      assert_nil result[:word_count]
    end

    test "dispatches .pdf to FilenameParser" do
      result = Parser.call("/tmp/Some Manual.pdf")
      assert_equal "Some Manual", result[:attributes][:title]
      assert_equal "pdf", result[:format]
    end

    test "captures EpubParser failures, falling back to filename" do
      result = Parser.call(FIXTURES.join("corrupt.epub").to_s)
      assert_equal "corrupt", result[:attributes][:title]
      assert_equal "epub", result[:format]
      assert_match(/Could not parse EPUB/, result[:parse_error])
    end

    test "uses object_key for the filename fallback when provided" do
      result = Parser.call(FIXTURES.join("corrupt.epub").to_s, object_key: "verne/Jules Verne - Insula.epub")
      assert_equal "Insula", result[:attributes][:title]
      assert_equal "Jules Verne", result[:attributes][:author]
      assert_equal "epub", result[:format]
    end

    test "unknown extension is parsed by filename, no error" do
      result = Parser.call("/tmp/something.txt")
      assert_equal "something", result[:attributes][:title]
      assert_not result.key?(:parse_error)
      assert_equal "pdf", result[:format]
    end
  end
end
