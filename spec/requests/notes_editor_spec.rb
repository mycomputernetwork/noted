require "rails_helper"

RSpec.describe "notes editor", type: :request do
  before { sign_in_as }

  it "the composer opens an editor over a note that does not exist yet" do
    expect { get new_note_path }.not_to change { Note.count }

    assert_response :success
    assert_select "turbo-frame#composer section.composer--open"
    assert_select "dialog", count: 0
    assert_select "textarea[name=?]", "note[body]"
  end

  it "a card opens the modal editor on its own note" do
    get note_path(notes(:owner_plain)), headers: { "Turbo-Frame" => "editor" }

    assert_response :success
    assert_select "turbo-frame#editor dialog.modal"
    assert_select "input[name=?][value=?]", "note[title]", notes(:owner_plain).title
  end

  it "both surfaces render the same fields" do
    get new_note_path
    composer = css_select(".editor input, .editor textarea, .editor select").map { |e| e["name"] }

    get note_path(notes(:owner_plain)), headers: { "Turbo-Frame" => "editor" }
    modal = css_select(".editor input, .editor textarea, .editor select").map { |e| e["name"] }

    assert_equal composer, modal
  end

  it "the editor lists the account's folders and no one else's" do
    get new_note_path

    assert_select "select[name=?] option", "note[folder_id]",
      count: owner.folders.count + 1
    assert_select "select[name=?] option[value=?]", "note[folder_id]",
      folders(:other_books).id.to_s, count: 0
  end

  it "another account's note has no editor" do
    get note_path(notes(:other_note))

    assert_response :not_found
  end

  it "an archived or trashed note has no editor" do
    get note_path(notes(:owner_archived))
    assert_response :not_found

    get note_path(notes(:owner_trashed))
    assert_response :not_found
  end

  it "the first keystroke creates the note and hands back where to save next" do
    expect { post api_v1_notes_path, params: { note: { title: "", body: "m" } } }
      .to change { owner.notes.count }.by(1)

    assert_response :created
    body = response.parsed_body
    note = owner.notes.order(:created_at).last

    assert_equal note.id, body["id"]
    assert_equal api_v1_note_path(note), body["url"]
    assert_equal "m", note.body
  end

  it "a created note belongs to the current account" do
    post api_v1_notes_path, params: { note: { body: "mine" } }

    assert_equal owner, owner.notes.order(:created_at).last.user
  end

  it "a folder from another account cannot be filed into" do
    expect { post api_v1_notes_path, params: { note: { body: "x", folder_id: folders(:other_books).id } } }
      .not_to change { Note.count }

    assert_response :unprocessable_content
  end

  it "saving replaces the fields it was given" do
    note = notes(:owner_plain)

    patch api_v1_note_path(note), params: {
      note: { title: "Renamed", body: "rewritten", folder_id: folders(:owner_groceries).id, pinned: "1" }
    }

    assert_response :success
    note.reload
    assert_equal "Renamed", note.title
    assert_equal "rewritten", note.body
    assert_equal folders(:owner_groceries), note.folder
    expect(note).to be_pinned
  end

  it "saving an unchanged folder does not move the note" do
    folder = folders(:owner_empty)
    first = owner.notes.create!(title: "First", body: "x", folder: folder, position: 0)
    second = owner.notes.create!(title: "Second", body: "x", folder: folder, position: 1)

    patch api_v1_note_path(second), params: { note: { body: "changed", folder_id: folder.id } }

    assert_response :success
    expect(first.reload.position).to eq(0)
    expect(second.reload.position).to eq(1)
  end

  it "clearing the folder unfiles the note rather than erroring" do
    note = notes(:owner_pinned)

    patch api_v1_note_path(note), params: { note: { folder_id: "" } }

    assert_response :success
    expect(note.reload.folder_id).to be_nil
  end

  it "another account's note cannot be saved over" do
    patch api_v1_note_path(notes(:other_note)), params: { note: { body: "overwritten" } }

    assert_response :not_found
    assert_equal "must never appear in owner's queries", notes(:other_note).reload.body
  end

  it "a note cannot be moved into another account's folder by update" do
    note = notes(:owner_plain)

    patch api_v1_note_path(note), params: { note: { folder_id: folders(:other_books).id } }

    assert_response :unprocessable_content
    expect(note.reload.folder_id).to be_nil
  end

  it "a note typed into and then emptied out is discarded on close" do
    note = owner.notes.create!(title: "", body: "")

    expect { delete api_v1_note_path(note) }.to change { Note.count }.by(-1)

    assert_response :no_content
  end

  it "a note with content is never discarded" do
    note = notes(:owner_plain)

    expect { delete api_v1_note_path(note) }.not_to change { Note.count }

    assert_response :unprocessable_content
    expect(note.reload).to be_persisted
  end

  it "another account's empty note cannot be discarded" do
    note = other.notes.create!(title: "", body: "")

    expect { delete api_v1_note_path(note) }.not_to change { Note.count }

    assert_response :not_found
  end

  it "every card links to its own editor" do
    get root_path

    assert_select "a.card__open[href=?]", note_path(notes(:owner_plain))
    assert_select "turbo-frame#composer a.composer[href=?]", new_note_path
    assert_select "turbo-frame#editor"
  end

  it "cards carry no pin badge" do
    get root_path

    assert_select ".board__heading", "Pinned"
    assert_select ".card__pin", count: 0
  end
end
