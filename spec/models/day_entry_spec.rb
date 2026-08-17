require "rails_helper"

RSpec.describe DayEntry, type: :model do
  it "kind is limited to event and action" do
    entry = owner.day_entries.build(kind: "reminder", date: Date.current, body: "x")
    expect(entry).not_to be_valid
    expect(entry.errors.attribute_names).to include(:kind)
  end

  it "only events may carry a time" do
    action = owner.day_entries.build(kind: "action", date: Date.current, body: "x", start_minute: 600)
    expect(action).not_to be_valid
    expect(action.errors.attribute_names).to include(:start_minute)

    event = owner.day_entries.build(kind: "event", date: Date.current, body: "x", start_minute: 600)
    expect(event).to be_valid
  end

  it "only actions may carry completion" do
    event = owner.day_entries.build(
      kind: "event", date: Date.current, body: "x", completed_at: Time.current
    )
    expect(event).not_to be_valid
    expect(event.errors.attribute_names).to include(:completed_at)
  end

  it "start_minute must be inside a day" do
    entry = owner.day_entries.build(kind: "event", date: Date.current, body: "x")

    entry.start_minute = 1440
    expect(entry).not_to be_valid

    entry.start_minute = -1
    expect(entry).not_to be_valid

    entry.start_minute = 1439
    expect(entry).to be_valid
  end

  it "start_time renders and round-trips" do
    entry = owner.day_entries.build(kind: "event", date: Date.current, body: "x")

    entry.start_minute = 0
    expect(entry.start_time).to eq("00:00")

    entry.start_minute = 14 * 60 + 5
    expect(entry.start_time).to eq("14:05")

    entry.start_time = "14:05"
    expect(entry.start_minute).to eq(845)
  end

  it "start_time parses the shapes a person actually types" do
    {
      "9:30"     => 570,
      "09:30"    => 570,
      "0930"     => 570,
      "9"        => 540,
      "2:30 pm"   => 870,
      "2:30pm"    => 870,
      "2:30 p.m." => 870,
      "12am"      => 0,
      "12:15 am"  => 15,
      "12:15 pm"  => 735,
      "23:59"     => 1439,
      "24:00"     => nil,
      "9:75"      => nil,
      ""          => nil,
      "later"     => nil
    }.each do |input, expected|
      actual = DayEntry.parse_minute(input)

      if expected.nil?
        expect(actual).to be_nil, "parsing #{input.inspect}"
      else
        expect(actual).to eq(expected), "parsing #{input.inspect}"
      end
    end
  end

  it "clearing start_time removes the minute" do
    entry = owner.day_entries.build(kind: "event", date: Date.current, body: "x", start_minute: 600)
    entry.start_time = ""
    expect(entry.start_minute).to be_nil
  end

  it "day order puts timed entries first in clock order then untimed" do
    ordered = owner.day_entries.on(Date.current).in_day_order.to_a

    expect(ordered.first).to eq(day_entries(:owner_timed_event))
    timed, untimed = ordered.partition(&:timed?)
    expect(ordered).to eq(timed + untimed)
    expect(timed.map(&:start_minute)).to eq(timed.map(&:start_minute).sort)
  end

  it "open excludes completed and trashed actions and all events" do
    open = owner.day_entries.open_actions

    expect(open).to include(day_entries(:owner_open_action))
    expect(open).not_to include(day_entries(:owner_done_action))
    expect(open).not_to include(day_entries(:owner_timed_event))

    day_entries(:owner_open_action).trash!
    expect(owner.day_entries.open_actions).not_to include(day_entries(:owner_open_action))
  end

  it "carried_into surfaces unfinished past actions and nothing else" do
    carried = owner.day_entries.carried_into(Date.current)

    expect(carried).to include(day_entries(:owner_overdue_action))
    expect(carried).not_to include(day_entries(:owner_old_done_action)),
      "a completed past action must not be carried forward"
    expect(carried).not_to include(day_entries(:owner_open_action)),
      "today's own actions are not 'carried' — they are already on the day"
  end

  it "rollover is a read, not a write — the original date is preserved" do
    original = day_entries(:owner_overdue_action).date
    owner.day_entries.carried_into(Date.current).to_a

    expect(day_entries(:owner_overdue_action).reload.date).to eq(original)
  end

  it "completing an action removes it from the carry" do
    day_entries(:owner_overdue_action).complete!

    expect(owner.day_entries.carried_into(Date.current)).not_to include(day_entries(:owner_overdue_action))
  end

  it "toggle flips completion both ways" do
    entry = day_entries(:owner_open_action)

    entry.toggle!
    expect(entry).to be_completed
    entry.toggle!
    expect(entry).to be_open
  end

  it "overdue? is only true for open actions in the past" do
    expect(day_entries(:owner_overdue_action)).to be_overdue
    expect(day_entries(:owner_old_done_action)).not_to be_overdue
    expect(day_entries(:owner_open_action)).not_to be_overdue
  end

  it "position is assigned per day on create" do
    date = Date.current + 40
    first  = owner.day_entries.create!(kind: "action", date: date, body: "one")
    second = owner.day_entries.create!(kind: "action", date: date, body: "two")

    expect(first.position).to eq(0)
    expect(second.position).to eq(1)
  end
end
