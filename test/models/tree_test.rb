require "test_helper"

# The sidebar tree (PRD §7.6).
class TreeTest < ActiveSupport::TestCase
  test "every folder gets a branch, including the empty ones" do
    tree = Tree.for(user: owner)

    assert_equal owner.folders.ordered.to_a, tree.folders
    assert_predicate tree.branch_for(folders(:owner_empty)), :empty?
  end

  test "notes hang off the folder they are filed in" do
    branch = Tree.for(user: owner).branch_for(folders(:owner_books))

    assert_includes branch.notes.map(&:id), notes(:owner_pinned).id
  end

  test "unfiled notes sit at the root rather than nowhere" do
    ids = Tree.for(user: owner).unfiled.map(&:id)

    assert_includes ids, notes(:owner_plain).id
    assert_includes ids, notes(:owner_untitled).id
  end

  test "archived and trashed notes never appear in the tree" do
    ids = tree_ids(owner)

    assert_not_includes ids, notes(:owner_archived).id
    assert_not_includes ids, notes(:owner_trashed).id
  end

  test "no other account's folders or notes reach the tree" do
    tree = Tree.for(user: owner)

    assert_not_includes tree.folders.map(&:id), folders(:other_books).id
    assert_not_includes tree_ids(owner), notes(:other_note).id
  end

  # position orders the sidebar only (PRD §5), and is null until milestone 13
  # puts a hand on it.
  test "positioned notes sort before unpositioned ones" do
    placed = owner.notes.create!(title: "Zzz last alphabetically", body: "x", position: 0)

    assert_equal placed.id, Tree.for(user: owner).unfiled.first.id
  end

  test "unpositioned notes sort by the label the tree actually draws" do
    labels = Tree.for(user: owner).unfiled.map(&:tree_label)

    assert_equal labels.sort_by(&:downcase), labels
  end

  test "an untitled note is labelled by its first line and nothing more" do
    assert_equal "the way sound carries over water", notes(:owner_untitled).tree_label
  end

  test "a note with neither title nor body still has a label" do
    assert_equal "Untitled", owner.notes.create!(title: nil, body: "").tree_label
  end

  test "the tree is two queries regardless of how many folders there are" do
    owner.folders.create!(name: "Another")
    owner.folders.create!(name: "And another")

    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      tree = Tree.for(user: owner)
      tree.branches.each { |branch| branch.notes.map(&:tree_label) }
      tree.unfiled.map(&:tree_label)
    end

    assert_equal 2, queries
  end

  private
    def tree_ids(user)
      tree = Tree.for(user: user)
      tree.branches.flat_map { |branch| branch.notes.map(&:id) } + tree.unfiled.map(&:id)
    end
end
