require "test_helper"

class LocaleKeysTest < ActiveSupport::TestCase
  test "app name resolves in Romanian" do
    assert_equal "Familioteca", I18n.t("app.name", locale: :ro)
  end

  test "sign-in keys exist" do
    assert_equal "Autentificare", I18n.t("sessions.new.title", locale: :ro)
    assert_equal "Email", I18n.t("sessions.new.email", locale: :ro)
    assert_equal "Parolă", I18n.t("sessions.new.password", locale: :ro)
    assert_equal "Intră în cont", I18n.t("sessions.new.submit", locale: :ro)
    assert_equal "Email sau parolă greșite.", I18n.t("sessions.new.invalid", locale: :ro)
  end

  test "sign-out key exists" do
    assert_equal "Deconectare", I18n.t("sessions.destroy.link", locale: :ro)
  end

  test "empty catalog key exists" do
    assert_equal "Niciun titlu disponibil", I18n.t("books.index.empty", locale: :ro)
  end
end
