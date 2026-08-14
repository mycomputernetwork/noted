require "test_helper"

class DayLogTest < ActiveSupport::TestCase
  test "a day has at most one log" do
    duplicate = owner.day_logs.build(date: day_logs(:owner_today).date, body: "again")

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :date
  end

  test "written excludes blank logs" do
    blank = owner.day_logs.create!(date: Date.current + 50, body: "")

    assert_includes owner.day_logs.written, day_logs(:owner_today)
    assert_not_includes owner.day_logs.written, blank
    assert blank.empty?
  end

  test "the log is plain text and carries no markup handling" do
    log = day_logs(:owner_today)
    log.update!(body: "**not bold** <b>not html</b>")

    assert_equal "**not bold** <b>not html</b>", log.reload.body
  end

  test "in_year is bounded to the calendar year" do
    edge = owner.day_logs.create!(date: Date.new(Date.current.year, 12, 31), body: "last day")
    outside = owner.day_logs.create!(date: Date.new(Date.current.year + 1, 1, 1), body: "next year")

    logs = owner.day_logs.in_year(Date.current.year)
    assert_includes logs, edge
    assert_not_includes logs, outside
  end
end
