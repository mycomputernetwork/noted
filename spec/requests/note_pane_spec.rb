require "rails_helper"

RSpec.describe "note pane", type: :request do
  before { sign_in_as }

  it "a note opened plainly fills the pane" do
    get note_path(notes(:owner_plain))

    assert_response :success
    assert_select "main.pane"
    assert_select "dialog", count: 0
    assert_select "textarea[name=?]", "note[body]", text: notes(:owner_plain).body
  end

  it "the same URL asked for through the editor frame is the modal" do
    get note_path(notes(:owner_plain)), headers: { "Turbo-Frame" => "editor" }

    assert_response :success
    assert_select "turbo-frame#editor dialog.modal"
    assert_select "main.pane", count: 0
  end

  it "the pane renders the same fields as the modal" do
    get note_path(notes(:owner_plain))
    pane = css_select(".editor input, .editor textarea, .editor select").map { |e| e["name"] }

    get note_path(notes(:owner_plain)), headers: { "Turbo-Frame" => "editor" }
    modal = css_select(".editor input, .editor textarea, .editor select").map { |e| e["name"] }

    assert_equal modal, pane
  end

  it "the pane mounts the same autosave controller, pointed at this note" do
    get note_path(notes(:owner_plain))

    assert_select "[data-controller~=autosave][data-autosave-url-value=?]",
      api_v1_note_path(notes(:owner_plain))
  end

  it "the pane has no close button" do
    get note_path(notes(:owner_plain))

    assert_select ".editor__close", count: 0
  end

  it "back goes to the board the note came from" do
    get note_path(notes(:owner_pinned))
    assert_select "a.pane__back[href=?]", folder_path(folders(:owner_books))

    get note_path(notes(:owner_plain))
    assert_select "a.pane__back[href=?]", root_path
  end

  it "another account's note has no pane either" do
    get note_path(notes(:other_note))

    assert_response :not_found
  end
end
