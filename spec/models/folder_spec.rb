require "rails_helper"

RSpec.describe Folder, type: :model do
  it "position is assigned on create and appends to the end" do
    folder = owner.folders.create!(name: "Recipes")

    expect(folder.position).to eq(owner.folders.maximum(:position))
    expect(owner.folders.ordered.last).to eq(folder)
  end

  it "reorder_to rewrites positions in the given order" do
    a = folders(:owner_books)
    b = folders(:owner_groceries)

    owner.folders.reorder_to([ b.id, a.id ])

    expect(owner.folders.ordered.to_a.first(2)).to eq([ b, a ])
  end

  it "moves between folders and compacts positions" do
    books = folders(:owner_books)
    groceries = folders(:owner_groceries)
    empty = folders(:owner_empty)

    expect(empty.move_in_tree(before_id: books.id)).to be(true)

    expect(owner.folders.kept.ordered.to_a).to eq([ empty, books, groceries ])
    expect(owner.folders.kept.ordered.map(&:position)).to eq([ 0, 1, 2 ])
  end

  it "rejects another account's insert target" do
    folder = folders(:owner_books)

    expect(folder.move_in_tree(before_id: folders(:other_books).id)).to be(false)

    expect(folder.reload.position).to eq(0)
  end

  it "names are stripped and required" do
    expect(owner.folders.build(name: "  Books  ").name).to eq("Books")
    expect(owner.folders.build(name: "   ")).not_to be_valid
  end

  it "a duplicate name is allowed within an account" do
    expect { owner.folders.create!(name: folders(:owner_books).name) }.not_to raise_error
  end

  it "folders are flat — there is no parent" do
    expect(Folder.column_names).not_to include("parent_id")
    expect(Folder.new).not_to respond_to(:parent)
  end

  it "clears a note's folder board position when the folder is deleted" do
    folder = owner.folders.create!(name: "Temporary")
    note = owner.notes.create!(title: "Filed", folder: folder, folder_board_position: 3)

    Folder.delete(folder.id)

    expect(note.reload).to have_attributes(folder_id: nil, folder_board_position: nil)
  end
end
