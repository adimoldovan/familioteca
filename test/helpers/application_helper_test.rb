require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "format_reading_time rounds up to a 30-minute minimum for short books" do
    assert_equal "30 de minute", format_reading_time(11)
    assert_equal "30 de minute", format_reading_time(40) # 40 → nearest half hour is 30
  end

  test "format_reading_time rounds to the nearest half hour" do
    assert_equal "o oră", format_reading_time(45)        # 45 → 60
    assert_equal "o oră și 30 de minute", format_reading_time(75)  # 75 → 90
    assert_equal "2 ore și 30 de minute", format_reading_time(135) # 135 → 150
  end

  test "format_reading_time renders whole hours without minutes" do
    assert_equal "o oră", format_reading_time(60)
    assert_equal "3 ore", format_reading_time(180)
  end

  test "format_reading_time is nil for nil or non-positive input" do
    assert_nil format_reading_time(nil)
    assert_nil format_reading_time(0)
    assert_nil format_reading_time(-5)
  end
end
