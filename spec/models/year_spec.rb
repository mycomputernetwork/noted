require "rails_helper"

RSpec.describe Year, type: :model do
  let(:year) { Year.for(user: owner, number: Date.current.year) }

  it "covers every day of the calendar year" do
    expected = Date.leap?(Date.current.year) ? 366 : 365

    expect(year.days.size).to eq(expected)
    expect(year.days.first.date).to eq(Date.new(Date.current.year, 1, 1))
    expect(year.days.last.date).to eq(Date.new(Date.current.year, 12, 31))
  end

  it "builds in a bounded number of queries regardless of content" do
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

    expect(queries).to be <= 5, "a year render must not be one query per day"
  end

  it "today is marked exactly once" do
    expect(year.days.count(&:today?)).to eq(1)
    expect(year.days.find(&:today?).date).to eq(Date.current)
  end

  it "carried actions land on today only" do
    today = year.days.find(&:today?)
    expect(today.carried).to include(day_entries(:owner_overdue_action))

    others = year.days.reject(&:today?)
    expect(others.all? { |day| day.carried.empty? }).to be(true),
      "an overdue action must not ghost onto every other day"
  end

  it "a year without today carries nothing" do
    past = Year.for(user: owner, number: Date.current.year - 1)

    expect(past.contains_today?).to be_falsey
    expect(past.days.all? { |day| day.carried.empty? }).to be(true)
  end

  it "empty days are empty and written days are not" do
    today = year.days.find(&:today?)
    expect(today).not_to be_empty

    blank = year.days.find { |day| day.entries.empty? && day.carried.empty? && day.log.nil? }

    expect(blank).not_to be_nil, "the fixture year should contain at least one untouched day"
    expect(blank).to be_empty
  end

  it "weekends are identifiable without reading the date" do
    weekend = year.days.select(&:weekend?)

    expect(weekend.all? { |day| day.date.saturday? || day.date.sunday? }).to be(true)
    expect(year.days.first(7).count(&:weekend?)).to eq(2),
      "every seven consecutive days contain exactly two weekend days"
    expect(weekend.size).to be >= 104
  end

  it "month starts are the sticky-header anchors" do
    expect(year.days.count(&:month_start?)).to eq(12)
  end

  it "navigation points at the adjacent years" do
    expect(year.previous).to eq(Date.current.year - 1)
    expect(year.next).to eq(Date.current.year + 1)
  end
end
