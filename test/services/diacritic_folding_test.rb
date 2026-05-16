require "test_helper"

class DiacriticFoldingTest < ActiveSupport::TestCase
  test "folds modern Romanian diacritics" do
    assert_equal "asa si asa", DiacriticFolding.fold("așa și așa")
    assert_equal "bizant", DiacriticFolding.fold("Bizanț")
    assert_equal "tara", DiacriticFolding.fold("Țară")
    assert_equal "inceput", DiacriticFolding.fold("Început")
    assert_equal "carti", DiacriticFolding.fold("cărți")
    assert_equal "manastire", DiacriticFolding.fold("Mănăstire")
  end

  test "folds old-style cedilla forms (ş ţ)" do
    assert_equal "asa", DiacriticFolding.fold("aşa")
    assert_equal "tara", DiacriticFolding.fold("Ţară")
  end

  test "leaves ASCII text unchanged except case" do
    assert_equal "hello world", DiacriticFolding.fold("Hello World")
  end

  test "folds NFD-decomposed diacritics" do
    nfd = "așa și Țară".unicode_normalize(:nfd)
    assert_equal "asa si tara", DiacriticFolding.fold(nfd)
  end

  test "handles nil and empty string" do
    assert_nil DiacriticFolding.fold(nil)
    assert_equal "", DiacriticFolding.fold("")
  end
end
