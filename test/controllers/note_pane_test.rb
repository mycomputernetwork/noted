require "test_helper"

# The full-pane note (PRD §7.7) and the surface rule behind it (§8.4): one
# URL, two frames, and which one you get follows where you clicked.
class NotePaneTest < ActionDispatch::IntegrationTest
  test "a note opened plainly fills the pane" do
    get note_path(notes(:owner_plain))

    assert_response :success
    assert_select "main.pane"
    assert_select "dialog", count: 0
    assert_select "textarea[name=?]", "note[body]", text: notes(:owner_plain).body
  end

  test "the same URL asked for through the editor frame is the modal" do
    get note_path(notes(:owner_plain)), headers: { "Turbo-Frame" => "editor" }

    assert_response :success
    assert_select "turbo-frame#editor dialog.modal"
    assert_select "main.pane", count: 0
  end

  # Three surfaces, one save path. If the pane needed different fields, the
  # milestone 3 split was wrong.
  test "the pane renders the same fields as the modal" do
    get note_path(notes(:owner_plain))
    pane = css_select(".editor input, .editor textarea, .editor select").map { |e| e["name"] }

    get note_path(notes(:owner_plain)), headers: { "Turbo-Frame" => "editor" }
    modal = css_select(".editor input, .editor textarea, .editor select").map { |e| e["name"] }

    assert_equal modal, pane
  end

  test "the pane mounts the same autosave controller, pointed at this note" do
    get note_path(notes(:owner_plain))

    assert_select "[data-controller~=autosave][data-autosave-url-value=?]",
      note_path(notes(:owner_plain))
  end

  # Leaving is navigating away, and autosave flushes on turbo:before-visit.
  # A Done button here would be a save button by another name (§8.1).
  test "the pane has no close button" do
    get note_path(notes(:owner_plain))

    assert_select ".editor__close", count: 0
  end

  test "back goes to the board the note came from" do
    get note_path(notes(:owner_pinned))
    assert_select "a.pane__back[href=?]", folder_path(folders(:owner_books))

    get note_path(notes(:owner_plain))
    assert_select "a.pane__back[href=?]", root_path
  end

  test "another account's note has no pane either" do
    get note_path(notes(:other_note))

    assert_response :not_found
  end
end
