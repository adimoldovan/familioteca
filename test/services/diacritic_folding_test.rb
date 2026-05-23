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

  test "ascii_fold strips diacritics but preserves case" do
    assert_equal "Bizant", DiacriticFolding.ascii_fold("Bizanț")
    assert_equal "Tara de Dincolo", DiacriticFolding.ascii_fold("Țara de Dincolo")
    assert_equal "Lucian Boia", DiacriticFolding.ascii_fold("Lucian Boia")
    assert_equal "Ana sI Bogdan", DiacriticFolding.ascii_fold("Ana șI Bogdan")
  end

  test "ascii_fold handles nil and empty string" do
    assert_nil DiacriticFolding.ascii_fold(nil)
    assert_equal "", DiacriticFolding.ascii_fold("")
  end
end
