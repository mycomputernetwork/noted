require "test_helper"

class YearTest < ActiveSupport::TestCase
  setup { @year = Year.for(user: owner, number: Date.current.year) }

  test "covers every day of the calendar year" do
    expected = Date.leap?(Date.current.year) ? 366 : 365

    assert_equal expected, @year.days.size
    assert_equal Date.new(Date.current.year, 1, 1), @year.days.first.date
    assert_equal Date.new(Date.current.year, 12, 31), @year.days.last.date
  end

  test "builds in a bounded number of queries regardless of content" do
    queries = 0
    ignored = [ "SCHEMA", "TRANSACTION" ]
    counter = ->(*, payload) { queries += 1 unless ignored.include?(payload[:name]) }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      Year.for(user: owner, number: Date.current.year).days.each do |day|
        day.events
        day.actionable
        day.log_body
      end
    end

    assert_operator queries, :<=, 5,
      "a year render must not be one query per day"
  end

  test "today is marked exactly once" do
    assert_equal 1, @year.days.count(&:today?)
    assert_equal Date.current, @year.days.find(&:today?).date
  end

  test "carried actions land on today only" do
    today = @year.days.find(&:today?)
    assert_includes today.carried, day_entries(:owner_overdue_action)

    others = @year.days.reject(&:today?)
    assert others.all? { |day| day.carried.empty? },
      "an overdue action must not ghost onto every other day"
  end

  test "a year without today carries nothing" do
    past = Year.for(user: owner, number: Date.current.year - 1)

    assert_not past.contains_today?
    assert past.days.all? { |day| day.carried.empty? }
  end

  test "empty days are empty and written days are not" do
    today = @year.days.find(&:today?)
    assert_not today.empty?

    # Not `Date.current + 200` — that falls outside the year for most of the
    # second half of it, and find returns nil.
    blank = @year.days.find { |day| day.entries.empty? && day.carried.empty? && day.log.nil? }

    assert_not_nil blank, "the fixture year should contain at least one untouched day"
    assert blank.empty?
  end

  test "weekends are identifiable without reading the date" do
    weekend = @year.days.select(&:weekend?)

    assert weekend.all? { |day| day.date.saturday? || day.date.sunday? }
    assert_equal 2, @year.days.first(7).count(&:weekend?),
      "every seven consecutive days contain exactly two weekend days"
    assert_operator weekend.size, :>=, 104
  end

  test "month starts are the sticky-header anchors" do
    assert_equal 12, @year.days.count(&:month_start?)
  end

  test "navigation points at the adjacent years" do
    assert_equal Date.current.year - 1, @year.previous
    assert_equal Date.current.year + 1, @year.next
  end
end
