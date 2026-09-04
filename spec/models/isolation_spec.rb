require "rails_helper"

RSpec.describe "account isolation", type: :model do
  it "a user's notes never include another user's" do
    expect(owner.notes).not_to include(notes(:other_note))
    expect(owner.notes).to include(notes(:owner_plain))
  end

  it "a user's year docs never include another user's" do
    expect(owner.year_docs).to include(year_docs(:owner_current))
    expect(owner.year_docs).not_to include(year_docs(:other_current))
  end

  it "a note cannot be filed into another user's folder" do
    note = owner.notes.build(body: "trying to escape", folder: folders(:other_books))

    expect(note.save).to be_falsey
    expect(note.errors.attribute_names).to include(:folder)
  end

  it "destroying a user takes their entire workspace with them" do
    notes_lost = owner.notes.count
    years_lost = owner.year_docs.count

    expect { owner.destroy! }
      .to change { Note.count }.by(-notes_lost)
      .and change { YearDoc.count }.by(-years_lost)

    expect(notes(:other_note).reload).to be_persisted
    expect(year_docs(:other_current).reload).to be_persisted
  end

  it "a user finds a year through their own scope" do
    doc = owner.year_docs.find_by!(year: Date.current.year)

    expect(doc.body).to include("Standup")
    expect(doc.body).not_to include("Not yours")
  end
end
