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
end
