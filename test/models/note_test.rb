require "test_helper"

class NoteTest < ActiveSupport::TestCase
  test "notes have no concept of a date" do
    assert_not Note.column_names.include?("entry_date"),
      "notes must not be dateable — anything on a day is a DayEntry or a DayLog"
    assert_not Note.new.respond_to?(:entry_date)
  end

  test "kept excludes archived and trashed" do
    kept = owner.notes.kept

    assert_includes kept, notes(:owner_plain)
    assert_not_includes kept, notes(:owner_archived)
    assert_not_includes kept, notes(:owner_trashed)
  end

  test "archived and trashed scopes do not overlap" do
    assert_includes owner.notes.archived, notes(:owner_archived)
    assert_not_includes owner.notes.archived, notes(:owner_trashed)
    assert_includes owner.notes.trashed, notes(:owner_trashed)
  end

  test "pinned notes sort first regardless of sort column or direction" do
    %w[edited created].product(%w[asc desc]).each do |by, direction|
      first = owner.notes.kept.sorted(by: by, direction: direction).first
      assert first.pinned?, "expected a pinned note first for #{by}/#{direction}"
    end
  end

  test "an unknown sort key falls back to last edited instead of raising" do
    assert_nothing_raised { owner.notes.sorted(by: "bogus").to_a }
  end

  test "archiving and trashing are reversible" do
    note = notes(:owner_plain)

    note.archive!
    assert note.archived?
    note.unarchive!
    assert_not note.archived?

    note.trash!
    assert note.trashed?
    note.restore!
    assert_not note.trashed?
  end

  test "trashing clears the archived flag so a note is in exactly one place" do
    note = notes(:owner_archived)
    note.trash!

    assert note.trashed?
    assert_not note.archived?
    assert_not_includes owner.notes.archived, note
  end

  test "empty? covers a note created on first keystroke and abandoned" do
    assert owner.notes.build(title: nil, body: "").empty?
    assert_not owner.notes.build(title: nil, body: "x").empty?
    assert_not owner.notes.build(title: "x", body: "").empty?
  end

  test "preview clamps to the requested number of lines" do
    note = owner.notes.build(body: (1..20).map { |n| "line #{n}" }.join("\n"))

    assert_equal 12, note.preview.lines.count
    assert_equal 3, note.preview(lines: 3).lines.count
  end

  test "deleting a folder unfiles its notes rather than deleting them" do
    note = notes(:owner_pinned)
    assert_equal folders(:owner_books), note.folder

    assert_no_difference -> { Note.count } do
      folders(:owner_books).destroy!
    end

    assert_nil note.reload.folder_id
  end
end
