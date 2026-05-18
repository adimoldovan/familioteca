require "test_helper"
require "fugit"

class RecurringScheduleTest < ActiveSupport::TestCase
  test "production schedule includes daily IngestBookJob at 03:00" do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    entry = config.dig("production", "daily_book_ingest")
    refute_nil entry, "expected daily_book_ingest entry"
    assert_equal "IngestBookJob", entry["class"]

    cron = Fugit.parse(entry["schedule"])
    refute_nil cron, "schedule must be parseable by Fugit"
    assert_equal 3, cron.next_time.hour, "job must be scheduled at 03:xx"
  end
end
