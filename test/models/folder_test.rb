require "test_helper"

class FolderTest < ActiveSupport::TestCase
  test "position is assigned on create and appends to the end" do
    folder = owner.folders.create!(name: "Recipes")

    assert_equal owner.folders.maximum(:position), folder.position
    assert_equal folder, owner.folders.ordered.last
  end

  test "reorder_to rewrites positions in the given order" do
    a = folders(:owner_books)
    b = folders(:owner_groceries)

    # Called through the user's relation, never on the global scope.
    owner.folders.reorder_to([ b.id, a.id ])

    # Only the ids passed in are rewritten; anything else keeps the position
    # it had and sorts after them.
    assert_equal [ b, a ], owner.folders.ordered.to_a.first(2)
  end

  test "names are stripped and required" do
    assert_equal "Books", owner.folders.build(name: "  Books  ").name
    assert_not owner.folders.build(name: "   ").valid?
  end

  test "folders are flat — there is no parent" do
    assert_not Folder.column_names.include?("parent_id")
    assert_not Folder.new.respond_to?(:parent)
  end
end
