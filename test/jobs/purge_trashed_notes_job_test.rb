require "test_helper"

class PurgeTrashedNotesJobTest < ActiveSupport::TestCase
  test "purges only what has been in the trash longer than the retention" do
    old = owner.notes.create!(title: "Old", body: "x", deleted_at: 31.days.ago)
    recent = notes(:owner_trashed)

    PurgeTrashedNotesJob.perform_now

    assert_not Note.exists?(old.id)
    assert Note.exists?(recent.id)
  end

  test "never touches live or archived notes" do
    assert_no_difference -> { owner.notes.kept.count + owner.notes.archived.count } do
      PurgeTrashedNotesJob.perform_now
    end
  end

  test "purges trashed day entries too" do
    entry = owner.day_entries.create!(
      kind: "action", date: 40.days.ago.to_date, body: "gone", deleted_at: 31.days.ago
    )

    PurgeTrashedNotesJob.perform_now

    assert_not DayEntry.exists?(entry.id)
  end

  test "retention is configurable so the sweep can be tested and tuned" do
    recent = notes(:owner_trashed)

    PurgeTrashedNotesJob.perform_now(retention: 1.day)

    assert_not Note.exists?(recent.id)
  end
end
