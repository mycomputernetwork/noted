require "rails_helper"

RSpec.describe Note, type: :model do
  it "notes have no concept of a date" do
    expect(Note.column_names).not_to include("entry_date")
    expect(Note.new).not_to respond_to(:entry_date)
  end

  it "kept excludes archived and trashed" do
    kept = owner.notes.kept

    expect(kept).to include(notes(:owner_plain))
    expect(kept).not_to include(notes(:owner_archived))
    expect(kept).not_to include(notes(:owner_trashed))
  end

  it "archived and trashed scopes do not overlap" do
    expect(owner.notes.archived).to include(notes(:owner_archived))
    expect(owner.notes.archived).not_to include(notes(:owner_trashed))
    expect(owner.notes.trashed).to include(notes(:owner_trashed))
  end

  it "pinned notes sort first regardless of sort column or direction" do
    %w[edited created].product(%w[asc desc]).each do |by, direction|
      first = owner.notes.kept.sorted(by: by, direction: direction).first
      expect(first).to be_pinned, "expected a pinned note first for #{by}/#{direction}"
    end
  end

  it "an unknown sort key falls back to last edited instead of raising" do
    expect { owner.notes.sorted(by: "bogus").to_a }.not_to raise_error
  end

  it "archiving and trashing are reversible" do
    note = notes(:owner_plain)

    note.archive!
    expect(note).to be_archived
    note.unarchive!
    expect(note).not_to be_archived

    note.trash!
    expect(note).to be_trashed
    note.restore!
    expect(note).not_to be_trashed
  end

  it "trashing clears the archived flag so a note is in exactly one place" do
    note = notes(:owner_archived)
    note.trash!

    expect(note).to be_trashed
    expect(note).not_to be_archived
    expect(owner.notes.archived).not_to include(note)
  end

  it "empty? covers a note created on first keystroke and abandoned" do
    expect(owner.notes.build(title: nil, body: "")).to be_empty
    expect(owner.notes.build(title: nil, body: "x")).not_to be_empty
    expect(owner.notes.build(title: "x", body: "")).not_to be_empty
  end

  it "preview clamps to the requested number of lines" do
    note = owner.notes.build(body: (1..20).map { |n| "line #{n}" }.join("\n"))

    expect(note.preview.lines.count).to eq(12)
    expect(note.preview(lines: 3).lines.count).to eq(3)
  end

  it "prepending into a folder rewrites the destination order" do
    note = notes(:owner_plain)
    folder = folders(:owner_books)

    expect(note.move_in_tree(folder_id: folder.id)).to be(true)

    branch = Tree.for(user: owner).branch_for(folder)
    expect(branch.notes.map(&:id).first(2)).to eq([ note.id, notes(:owner_pinned).id ])
    expect(branch.notes.map(&:position).first(2)).to eq([ 0, 1 ])
  end

  it "moving between notes backfills and compacts the list" do
    folder = folders(:owner_empty)
    a = owner.notes.create!(title: "Alpha", body: "x", folder: folder)
    b = owner.notes.create!(title: "Bravo", body: "x", folder: folder)
    c = owner.notes.create!(title: "Charlie", body: "x", folder: folder)

    expect(c.move_in_tree(folder_id: folder.id, before_id: b.id)).to be(true)

    branch = Tree.for(user: owner).branch_for(folder)
    expect(branch.notes.map(&:id)).to eq([ a.id, c.id, b.id ])
    expect(branch.notes.map(&:position)).to eq([ 0, 1, 2 ])
  end

  it "compacts the source list when a note leaves it" do
    folder = folders(:owner_empty)
    a = owner.notes.create!(title: "Alpha", body: "x", folder: folder, position: 0)
    b = owner.notes.create!(title: "Bravo", body: "x", folder: folder, position: 1)

    expect(a.move_in_tree(folder_id: nil)).to be(true)

    expect(b.reload.position).to eq(0)
    expect(a.reload.folder_id).to be_nil
  end

  it "rejects another account's insert target" do
    note = notes(:owner_plain)

    expect(note.move_in_tree(folder_id: nil, before_id: notes(:other_note).id)).to be(false)

    expect(note.reload.folder_id).to be_nil
  end

  it "deleting a folder unfiles its notes rather than deleting them" do
    note = notes(:owner_pinned)
    expect(note.folder).to eq(folders(:owner_books))

    expect { folders(:owner_books).destroy! }.not_to change { Note.count }

    expect(note.reload.folder_id).to be_nil
  end
end
