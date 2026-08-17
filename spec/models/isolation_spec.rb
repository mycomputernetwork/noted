require "rails_helper"

RSpec.describe "account isolation", type: :model do
  it "a user's notes never include another user's" do
    expect(owner.notes).not_to include(notes(:other_note))
    expect(owner.notes).to include(notes(:owner_plain))
  end

  it "a user's day entries and logs never include another user's" do
    expect(owner.day_entries).not_to include(day_entries(:other_event))
    expect(owner.day_logs).not_to include(day_logs(:other_today))
  end

  it "a note cannot be filed into another user's folder" do
    note = owner.notes.build(body: "trying to escape", folder: folders(:other_books))

    expect(note.save).to be_falsey
    expect(note.errors.attribute_names).to include(:folder)
  end

  it "a day log date is unique per user but may repeat across users" do
    expect(day_logs(:other_today)).to be_persisted

    duplicate = owner.day_logs.build(date: Date.current, body: "second log")
    expect(duplicate).not_to be_valid
  end

  it "destroying a user takes their entire workspace with them" do
    notes_lost = owner.notes.count
    entries_lost = owner.day_entries.count

    expect { owner.destroy! }
      .to change { Note.count }.by(-notes_lost)
      .and change { DayEntry.count }.by(-entries_lost)

    expect(notes(:other_note).reload).to be_persisted
  end

  it "Year is built from one user's records only" do
    year = Year.for(user: owner, number: Date.current.year)
    bodies = year.days.flat_map(&:entries).map(&:body)

    expect(bodies).to include("Standup")
    expect(bodies).not_to include("Not yours")
  end
end
