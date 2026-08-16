require "test_helper"

# The editor's endpoints (PRD §8.2). They answer the autosave controller, not
# a form: JSON in, JSON out, no redirects.
class NotesEditorTest < ActionDispatch::IntegrationTest
  # --- Opening -------------------------------------------------------------

  # The composer expands in place; it is not a dialog (PRD §8.2).
  test "the composer opens an editor over a note that does not exist yet" do
    assert_no_difference -> { Note.count } do
      get new_note_path
    end

    assert_response :success
    assert_select "turbo-frame#composer section.composer--open"
    assert_select "dialog", count: 0
    assert_select "textarea[name=?]", "note[body]"
  end

  # A card does open a dialog: there is a board behind it worth keeping in
  # view, which is the whole distinction in §8.4.
  test "a card opens the modal editor on its own note" do
    get note_path(notes(:owner_plain)), headers: { "Turbo-Frame" => "editor" }

    assert_response :success
    assert_select "turbo-frame#editor dialog.modal"
    assert_select "input[name=?][value=?]", "note[title]", notes(:owner_plain).title
  end

  test "both surfaces render the same fields" do
    get new_note_path
    composer = css_select(".editor input, .editor textarea, .editor select").map { |e| e["name"] }

    get note_path(notes(:owner_plain)), headers: { "Turbo-Frame" => "editor" }
    modal = css_select(".editor input, .editor textarea, .editor select").map { |e| e["name"] }

    assert_equal composer, modal
  end

  # Both accounts have a folder called "Books", so a name match proves
  # nothing here — the count is what proves the select was scoped.
  test "the editor lists the account's folders and no one else's" do
    get new_note_path

    assert_select "select[name=?] option", "note[folder_id]",
      count: owner.folders.count + 1  # + "No folder"
    assert_select "select[name=?] option[value=?]", "note[folder_id]",
      folders(:other_books).id.to_s, count: 0
  end

  # An id from another account has to miss, not load (PRD §5). The board never
  # renders a link to one; this is the direct-URL path.
  test "another account's note has no editor" do
    get note_path(notes(:other_note))

    assert_response :not_found
  end

  test "an archived or trashed note has no editor" do
    get note_path(notes(:owner_archived))
    assert_response :not_found

    get note_path(notes(:owner_trashed))
    assert_response :not_found
  end

  # --- Create on first keystroke -------------------------------------------

  test "the first keystroke creates the note and hands back where to save next" do
    assert_difference -> { owner.notes.count }, 1 do
      post notes_path, params: { note: { title: "", body: "m" } }
    end

    assert_response :created
    body = response.parsed_body
    note = owner.notes.order(:created_at).last

    assert_equal note.id, body["id"]
    assert_equal note_path(note), body["url"]
    assert_equal "m", note.body
  end

  test "a created note belongs to the current account" do
    post notes_path, params: { note: { body: "mine" } }

    assert_equal owner, owner.notes.order(:created_at).last.user
  end

  test "a folder from another account cannot be filed into" do
    assert_no_difference -> { Note.count } do
      post notes_path, params: { note: { body: "x", folder_id: folders(:other_books).id } }
    end

    assert_response :unprocessable_content
  end

  # --- Update --------------------------------------------------------------

  test "saving replaces the fields it was given" do
    note = notes(:owner_plain)

    patch note_path(note), params: {
      note: { title: "Renamed", body: "rewritten", folder_id: folders(:owner_groceries).id, pinned: "1" }
    }

    assert_response :success
    note.reload
    assert_equal "Renamed", note.title
    assert_equal "rewritten", note.body
    assert_equal folders(:owner_groceries), note.folder
    assert note.pinned?
  end

  test "clearing the folder unfiles the note rather than erroring" do
    note = notes(:owner_pinned)

    patch note_path(note), params: { note: { folder_id: "" } }

    assert_response :success
    assert_nil note.reload.folder_id
  end

  test "another account's note cannot be saved over" do
    patch note_path(notes(:other_note)), params: { note: { body: "overwritten" } }

    assert_response :not_found
    assert_equal "must never appear in owner's queries", notes(:other_note).reload.body
  end

  test "a note cannot be moved into another account's folder by update" do
    note = notes(:owner_plain)

    patch note_path(note), params: { note: { folder_id: folders(:other_books).id } }

    assert_response :unprocessable_content
    assert_nil note.reload.folder_id
  end

  # --- Discard -------------------------------------------------------------

  test "a note typed into and then emptied out is discarded on close" do
    note = owner.notes.create!(title: "", body: "")

    assert_difference -> { Note.count }, -1 do
      delete note_path(note)
    end

    assert_response :no_content
  end

  test "a note with content is never discarded" do
    note = notes(:owner_plain)

    assert_no_difference -> { Note.count } do
      delete note_path(note)
    end

    assert_response :unprocessable_content
    assert note.reload.persisted?
  end

  test "another account's empty note cannot be discarded" do
    note = other.notes.create!(title: "", body: "")

    assert_no_difference -> { Note.count } do
      delete note_path(note)
    end

    assert_response :not_found
  end

  # --- The board ------------------------------------------------------------

  test "every card links to its own editor" do
    get root_path

    assert_select "a.card__open[href=?]", note_path(notes(:owner_plain))
    assert_select "turbo-frame#composer a.composer[href=?]", new_note_path
    assert_select "turbo-frame#editor"
  end

  # The Pinned section already says it; a badge on each card repeats it.
  test "cards carry no pin badge" do
    get root_path

    assert_select ".board__heading", "Pinned"
    assert_select ".card__pin", count: 0
  end
end
