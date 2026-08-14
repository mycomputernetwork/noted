require "test_helper"

class DayEntryTest < ActiveSupport::TestCase
  test "kind is limited to event and action" do
    entry = owner.day_entries.build(kind: "reminder", date: Date.current, body: "x")
    assert_not entry.valid?
    assert_includes entry.errors.attribute_names, :kind
  end

  test "only events may carry a time" do
    action = owner.day_entries.build(kind: "action", date: Date.current, body: "x", start_minute: 600)
    assert_not action.valid?
    assert_includes action.errors.attribute_names, :start_minute

    event = owner.day_entries.build(kind: "event", date: Date.current, body: "x", start_minute: 600)
    assert event.valid?
  end

  test "only actions may carry completion" do
    event = owner.day_entries.build(
      kind: "event", date: Date.current, body: "x", completed_at: Time.current
    )
    assert_not event.valid?
    assert_includes event.errors.attribute_names, :completed_at
  end

  test "start_minute must be inside a day" do
    entry = owner.day_entries.build(kind: "event", date: Date.current, body: "x")

    entry.start_minute = 1440
    assert_not entry.valid?

    entry.start_minute = -1
    assert_not entry.valid?

    entry.start_minute = 1439
    assert entry.valid?
  end

  test "start_time renders and round-trips" do
    entry = owner.day_entries.build(kind: "event", date: Date.current, body: "x")

    entry.start_minute = 0
    assert_equal "00:00", entry.start_time

    entry.start_minute = 14 * 60 + 5
    assert_equal "14:05", entry.start_time

    entry.start_time = "14:05"
    assert_equal 845, entry.start_minute
  end

  test "start_time parses the shapes a person actually types" do
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
        assert_nil actual, "parsing #{input.inspect}"
      else
        assert_equal expected, actual, "parsing #{input.inspect}"
      end
    end
  end

  test "clearing start_time removes the minute" do
    entry = owner.day_entries.build(kind: "event", date: Date.current, body: "x", start_minute: 600)
    entry.start_time = ""
    assert_nil entry.start_minute
  end

  test "day order puts timed entries first in clock order then untimed" do
    ordered = owner.day_entries.on(Date.current).in_day_order.to_a

    assert_equal day_entries(:owner_timed_event), ordered.first
    timed, untimed = ordered.partition(&:timed?)
    assert_equal timed + untimed, ordered
    assert_equal timed.map(&:start_minute).sort, timed.map(&:start_minute)
  end

  test "open excludes completed and trashed actions and all events" do
    open = owner.day_entries.open_actions

    assert_includes open, day_entries(:owner_open_action)
    assert_not_includes open, day_entries(:owner_done_action)
    assert_not_includes open, day_entries(:owner_timed_event)

    day_entries(:owner_open_action).trash!
    assert_not_includes owner.day_entries.open_actions, day_entries(:owner_open_action)
  end

  test "carried_into surfaces unfinished past actions and nothing else" do
    carried = owner.day_entries.carried_into(Date.current)

    assert_includes carried, day_entries(:owner_overdue_action)
    assert_not_includes carried, day_entries(:owner_old_done_action),
      "a completed past action must not be carried forward"
    assert_not_includes carried, day_entries(:owner_open_action),
      "today's own actions are not 'carried' — they are already on the day"
  end

  test "rollover is a read, not a write — the original date is preserved" do
    original = day_entries(:owner_overdue_action).date
    owner.day_entries.carried_into(Date.current).to_a

    assert_equal original, day_entries(:owner_overdue_action).reload.date
  end

  test "completing an action removes it from the carry" do
    day_entries(:owner_overdue_action).complete!

    assert_not_includes owner.day_entries.carried_into(Date.current), day_entries(:owner_overdue_action)
  end

  test "toggle flips completion both ways" do
    entry = day_entries(:owner_open_action)

    entry.toggle!
    assert entry.completed?
    entry.toggle!
    assert entry.open?
  end

  test "overdue? is only true for open actions in the past" do
    assert day_entries(:owner_overdue_action).overdue?
    assert_not day_entries(:owner_old_done_action).overdue?
    assert_not day_entries(:owner_open_action).overdue?
  end

  test "position is assigned per day on create" do
    date = Date.current + 40
    first  = owner.day_entries.create!(kind: "action", date: date, body: "one")
    second = owner.day_entries.create!(kind: "action", date: date, body: "two")

    assert_equal 0, first.position
    assert_equal 1, second.position
  end
end
