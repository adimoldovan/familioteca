require "test_helper"

class LocaleConfigTest < ActiveSupport::TestCase
  test "default locale is Romanian" do
    assert_equal :ro, I18n.default_locale
  end

  test "available locales include :ro" do
    assert_includes I18n.available_locales, :ro
  end

  test "time zone is Bucharest" do
    assert_equal "Bucharest", Time.zone.name
  end
end
