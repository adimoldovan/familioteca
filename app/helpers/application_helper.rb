module ApplicationHelper
  # Formats an estimate in minutes, rounded to the nearest half hour (minimum
  # 30 min), as Romanian text: "30 de minute", "o oră", "o oră și 30 de minute",
  # "2 ore". Returns nil for nil/zero input so callers can skip rendering.
  def format_reading_time(minutes)
    return nil if minutes.nil? || minutes <= 0
    hours, mins = [ (minutes / 30.0).round * 30, 30 ].max.divmod(60)
    parts = []
    parts << t("reading_time.hours", count: hours) if hours.positive?
    parts << t("reading_time.minutes", count: mins) if mins.positive?
    parts.join(t("reading_time.connector"))
  end
end
