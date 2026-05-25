require "test_helper"

class LanguageNormalizerTest < ActiveSupport::TestCase
  test "normalizes ISO 639-1 code to full name" do
    assert_equal "Romanian", LanguageNormalizer.normalize("ro")
    assert_equal "English",  LanguageNormalizer.normalize("en")
    assert_equal "French",   LanguageNormalizer.normalize("fr")
  end

  test "normalizes BCP 47 tag to full name" do
    assert_equal "Romanian", LanguageNormalizer.normalize("ro-RO")
    assert_equal "English",  LanguageNormalizer.normalize("en-US")
    assert_equal "English",  LanguageNormalizer.normalize("en-GB")
    assert_equal "Portuguese", LanguageNormalizer.normalize("pt-BR")
  end

  test "normalizes full language name case-insensitively" do
    assert_equal "Romanian", LanguageNormalizer.normalize("Romanian")
    assert_equal "Romanian", LanguageNormalizer.normalize("romanian")
    assert_equal "English",  LanguageNormalizer.normalize("ENGLISH")
  end

  test "normalizes ISO 639-2 three-letter codes" do
    assert_equal "English",  LanguageNormalizer.normalize("eng")
    assert_equal "French",   LanguageNormalizer.normalize("fre")
    assert_equal "French",   LanguageNormalizer.normalize("fra")
    assert_equal "German",   LanguageNormalizer.normalize("deu")
    assert_equal "German",   LanguageNormalizer.normalize("ger")
    assert_equal "Romanian", LanguageNormalizer.normalize("ron")
    assert_equal "Romanian", LanguageNormalizer.normalize("rum")
  end

  test "handles regional subtags with two and three-letter codes" do
    assert_equal "English", LanguageNormalizer.normalize("en_US")
    assert_equal "English", LanguageNormalizer.normalize("eng-US")
  end

  test "returns nil for blank or nil input" do
    assert_nil LanguageNormalizer.normalize(nil)
    assert_nil LanguageNormalizer.normalize("")
    assert_nil LanguageNormalizer.normalize("   ")
  end

  test "passes through unknown values unchanged" do
    assert_equal "Klingon", LanguageNormalizer.normalize("Klingon")
  end
end
