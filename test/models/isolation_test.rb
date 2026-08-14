require "test_helper"

# The single most important property in the application: two accounts are
# fully independent workspaces and nothing crosses between them. Every other
# test can be rewritten later; these should survive every refactor.
class IsolationTest < ActiveSupport::TestCase
  test "a user's notes never include another user's" do
    assert_not_includes owner.notes, notes(:other_note)
    assert_includes owner.notes, notes(:owner_plain)
  end

  test "a user's day entries and logs never include another user's" do
    assert_not_includes owner.day_entries, day_entries(:other_event)
    assert_not_includes owner.day_logs, day_logs(:other_today)
  end

  test "folder names are unique per user, not globally" do
    assert_equal "Books", folders(:owner_books).name
    assert_equal "Books", folders(:other_books).name

    duplicate = owner.folders.build(name: "books")
    assert_not duplicate.valid?, "expected case-insensitive collision within the same user"
    assert_includes duplicate.errors.attribute_names, :name
  end

  test "a note cannot be filed into another user's folder" do
    note = owner.notes.build(body: "trying to escape", folder: folders(:other_books))

    assert_not note.save
    assert_includes note.errors.attribute_names, :folder
  end

  test "a day log date is unique per user but may repeat across users" do
    assert day_logs(:other_today).persisted?

    duplicate = owner.day_logs.build(date: Date.current, body: "second log")
    assert_not duplicate.valid?
  end

  test "destroying a user takes their entire workspace with them" do
    assert_difference -> { Note.count }, -owner.notes.count do
      assert_difference -> { DayEntry.count }, -owner.day_entries.count do
        owner.destroy!
      end
    end

    assert notes(:other_note).reload.persisted?
  end

  test "Year is built from one user's records only" do
    year = Year.for(user: owner, number: Date.current.year)
    bodies = year.days.flat_map(&:entries).map(&:body)

    assert_includes bodies, "Standup"
    assert_not_includes bodies, "Not yours"
  end
end
