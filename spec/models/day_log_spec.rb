require "rails_helper"

RSpec.describe DayLog, type: :model do
  it "a day has at most one log" do
    duplicate = owner.day_logs.build(date: day_logs(:owner_today).date, body: "again")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.attribute_names).to include(:date)
  end

  it "written excludes blank logs" do
    blank = owner.day_logs.create!(date: Date.current + 50, body: "")

    expect(owner.day_logs.written).to include(day_logs(:owner_today))
    expect(owner.day_logs.written).not_to include(blank)
    expect(blank).to be_empty
  end

  it "the log is plain text and carries no markup handling" do
    log = day_logs(:owner_today)
    log.update!(body: "**not bold** <b>not html</b>")

    expect(log.reload.body).to eq("**not bold** <b>not html</b>")
  end

  it "in_year is bounded to the calendar year" do
    edge = owner.day_logs.create!(date: Date.new(Date.current.year, 12, 31), body: "last day")
    outside = owner.day_logs.create!(date: Date.new(Date.current.year + 1, 1, 1), body: "next year")

    logs = owner.day_logs.in_year(Date.current.year)
    expect(logs).to include(edge)
    expect(logs).not_to include(outside)
  end
end
