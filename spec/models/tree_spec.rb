require "rails_helper"

RSpec.describe Tree, type: :model do
  def tree_ids(user)
    tree = Tree.for(user: user)
    tree.branches.flat_map { |branch| branch.notes.map(&:id) } + tree.unfiled.map(&:id)
  end

  it "every folder gets a branch, including the empty ones" do
    tree = Tree.for(user: owner)

    expect(tree.folders).to eq(owner.folders.ordered.to_a)
    expect(tree.branch_for(folders(:owner_empty))).to be_empty
  end

  it "notes hang off the folder they are filed in" do
    branch = Tree.for(user: owner).branch_for(folders(:owner_books))

    expect(branch.notes.map(&:id)).to include(notes(:owner_pinned).id)
  end

  it "unfiled notes sit at the root rather than nowhere" do
    ids = Tree.for(user: owner).unfiled.map(&:id)

    expect(ids).to include(notes(:owner_plain).id)
    expect(ids).to include(notes(:owner_untitled).id)
  end

  it "archived and trashed notes never appear in the tree" do
    ids = tree_ids(owner)

    expect(ids).not_to include(notes(:owner_archived).id)
    expect(ids).not_to include(notes(:owner_trashed).id)
  end

  it "no other account's folders or notes reach the tree" do
    tree = Tree.for(user: owner)

    expect(tree.folders.map(&:id)).not_to include(folders(:other_books).id)
    expect(tree_ids(owner)).not_to include(notes(:other_note).id)
  end

  it "positioned notes sort before unpositioned ones" do
    placed = owner.notes.create!(title: "Zzz last alphabetically", body: "x", position: 0)

    expect(Tree.for(user: owner).unfiled.first.id).to eq(placed.id)
  end

  it "unpositioned notes sort by the label the tree actually draws" do
    labels = Tree.for(user: owner).unfiled.map(&:tree_label)

    expect(labels).to eq(labels.sort_by(&:downcase))
  end

  it "an untitled note is labelled by its first line and nothing more" do
    expect(notes(:owner_untitled).tree_label).to eq("the way sound carries over water")
  end

  it "a note with neither title nor body still has a label" do
    expect(owner.notes.create!(title: nil, body: "").tree_label).to eq("Untitled")
  end

  it "the tree is two queries regardless of how many folders there are" do
    owner.folders.create!(name: "Another")
    owner.folders.create!(name: "And another")

    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      tree = Tree.for(user: owner)
      tree.branches.each { |branch| branch.notes.map(&:tree_label) }
      tree.unfiled.map(&:tree_label)
    end

    expect(queries).to eq(2)
  end
end
