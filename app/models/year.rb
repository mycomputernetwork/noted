# One calendar year of Days, built in three queries regardless of how much is
# in it. The whole year renders in a single page load — roughly 365 rows, most
# of them collapsed, is negligible DOM, and it avoids bidirectional infinite
# scroll having to compensate scroll position on every prepend of past days.
class Year
  attr_reader :number, :days, :today

  def self.for(user:, number: Date.current.year, today: Date.current)
    first = Date.new(number, 1, 1)
    last  = Date.new(number, 12, 31)

    entries = user.day_entries.kept.during(first..last).in_day_order.group_by(&:date)
    logs    = user.day_logs.during(first..last).index_by(&:date)

    # Open actions from before today are surfaced on today only. Ghosting them
    # onto every subsequent day would make the whole future look overdue.
    carried = today.year == number ? user.day_entries.carried_into(today).to_a : []

    days = (first..last).map do |date|
      Day.new(
        date: date,
        entries: entries.fetch(date, []),
        log: logs[date],
        carried: date == today ? carried : [],
        today: today
      )
    end

    new(number: number, days: days, today: today)
  end

  def initialize(number:, days:, today: Date.current)
    @number = number
    @days = days
    @today = today
  end

  def previous = number - 1
  def next     = number + 1

  def contains_today? = today.year == number

  def index_of_today
    days.index(&:today?)
  end

  def months = days.group_by { |day| day.date.month }
end
