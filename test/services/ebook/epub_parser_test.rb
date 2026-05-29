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

    test "extracts EPUB 2 cover declared via oldstyle meta" do
      result = EpubParser.call(FIXTURES.join("oldstyle-cover.epub").to_s)
      refute_nil result[:cover_io]
      assert_operator result[:cover_io].size, :>, 0
      assert_equal "image/png", result[:cover_content_type]
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

    test "reverses sort-name author to display name" do
      result = EpubParser.call(FIXTURES.join("sort-author.epub").to_s)
      assert_equal "Iulian Bocai", result[:attributes][:author]
    end

    test "counts words across spine documents, excluding scripts" do
      result = EpubParser.call(FIXTURES.join("word-count.epub").to_s)
      assert_equal 15, result[:word_count]
    end

    test "unsort_author_name reverses Last, First" do
      assert_equal "Iulian Bocai", EpubParser.unsort_author_name("Bocai, Iulian")
    end

    test "unsort_author_name handles compound names" do
      assert_equal "Jules Gabriel Verne", EpubParser.unsort_author_name("Verne, Jules Gabriel")
      assert_equal "Gabriel Garcia Marquez", EpubParser.unsort_author_name("Garcia Marquez, Gabriel")
    end

    test "unsort_author_name strips surrounding whitespace" do
      assert_equal "Iulian Bocai", EpubParser.unsort_author_name("  Bocai, Iulian  ")
    end

    test "unsort_author_name handles comma without space" do
      assert_equal "Iulian Bocai", EpubParser.unsort_author_name("Bocai,Iulian")
    end

    test "unsort_author_name leaves normal names unchanged" do
      assert_equal "Jules Verne", EpubParser.unsort_author_name("Jules Verne")
    end

    test "unsort_author_name preserves names with suffixes" do
      assert_equal "Martin Luther King, Jr.", EpubParser.unsort_author_name("Martin Luther King, Jr.")
    end

    test "unsort_author_name leaves multi-comma strings unchanged" do
      assert_equal "King, Jr., Martin Luther", EpubParser.unsort_author_name("King, Jr., Martin Luther")
    end

    test "unsort_author_name returns nil for nil" do
      assert_nil EpubParser.unsort_author_name(nil)
    end

    test "extracts goodreads_url from identifier" do
      result = EpubParser.call(FIXTURES.join("goodreads-id.epub").to_s)
      assert_equal "https://www.goodreads.com/book/show/62024", result[:attributes][:goodreads_url]
    end

    test "extracts goodreads_url from oldstyle meta" do
      result = EpubParser.call(FIXTURES.join("goodreads-meta.epub").to_s)
      assert_equal "https://www.goodreads.com/book/show/221174391-viata-e-prea-scurt", result[:attributes][:goodreads_url]
    end

    test "goodreads_url is nil when no identifier matches" do
      result = EpubParser.call(FIXTURES.join("well-tagged.epub").to_s)
      assert_nil result[:attributes][:goodreads_url]
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
