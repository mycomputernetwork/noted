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

  it "board order keeps pinned notes in their own zone" do
    first = owner.notes.kept.board_order.first

    expect(first).to be_pinned
  end

  it "board order uses manual positions before edited-time fallback" do
    first = owner.notes.create!(title: "First board note", body: "x", board_position: 2, updated_at: 1.day.ago)
    second = owner.notes.create!(title: "Second board note", body: "x", board_position: 1, updated_at: 1.week.ago)

    expect(owner.notes.kept.board_order).to include(second, first)
    expect(owner.notes.kept.board_order.index(second)).to be < owner.notes.kept.board_order.index(first)
  end

  it "a new note is placed before the current board" do
    older = owner.notes.create!(title: "Older board note", body: "x", board_position: 3)
    newer = owner.notes.create!(title: "Newer board note", body: "x")

    expect(newer.board_position).to be < older.board_position
  end

  it "reordering the board writes positions to the submitted visual order" do
    a = owner.notes.create!(title: "Board A", body: "x")
    b = owner.notes.create!(title: "Board B", body: "x")
    ids = owner.notes.kept.board_order.map(&:id)
    pinned_ids = owner.notes.kept.where(pinned: true).board_order.map(&:id)
    ids = [ *pinned_ids, a.id, b.id, *(ids - pinned_ids - [ a.id, b.id ]) ]

    expect(owner.notes.reorder_board(ids)).to be(true)

    expect(owner.notes.kept.where(pinned: false).board_order.first(2).map(&:id)).to eq([ a.id, b.id ])
    expect(a.reload.board_position).to be < b.reload.board_position
  end

  it "folder board order uses folder positions before global board fallback" do
    folder = folders(:owner_empty)
    fallback_first = owner.notes.create!(title: "Fallback first", body: "x", folder: folder, board_position: 1)
    fallback_second = owner.notes.create!(title: "Fallback second", body: "x", folder: folder, board_position: 2)
    fallback_first.update_column(:folder_board_position, nil)
    fallback_second.update_column(:folder_board_position, nil)
    folder_first = owner.notes.create!(title: "Folder first", body: "x", folder: folder, board_position: 99, folder_board_position: 0)

    expect(owner.notes.kept.where(folder: folder).folder_board_order.first(3)).to eq([ folder_first, fallback_first, fallback_second ])
  end

  it "reordering a folder board writes only folder positions" do
    folder = folders(:owner_empty)
    a = owner.notes.create!(title: "Folder A", body: "x", folder: folder, board_position: 10, folder_board_position: 10)
    b = owner.notes.create!(title: "Folder B", body: "x", folder: folder, board_position: 11, folder_board_position: 11)

    expect(owner.notes.reorder_board([ b.id, a.id ], folder_id: folder.id)).to be(true)

    expect(owner.notes.kept.where(folder: folder).folder_board_order.map(&:id)).to eq([ b.id, a.id ])
    expect(a.reload.board_position).to eq(10)
    expect(a.folder_board_position).to be > b.reload.folder_board_position
  end

  it "filing a note moves it to the front of the destination folder board" do
    note = notes(:owner_plain)
    folder = folders(:owner_empty)
    older = owner.notes.create!(title: "Already there", body: "x", folder: folder, folder_board_position: 5)

    expect(note.move_in_tree(folder_id: folder.id)).to be(true)

    expect(note.reload.folder_board_position).to be < older.reload.folder_board_position
    expect(owner.notes.kept.where(folder: folder).folder_board_order.first).to eq(note)
  end

  it "unfiling a note clears its folder board position" do
    note = owner.notes.create!(title: "Filed", body: "x", folder: folders(:owner_empty), folder_board_position: 3)

    expect(note.move_in_tree(folder_id: nil)).to be(true)

    expect(note.reload.folder_board_position).to be_nil
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
