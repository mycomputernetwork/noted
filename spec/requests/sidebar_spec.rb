require "rails_helper"

RSpec.describe "sidebar", type: :request do
  before { sign_in_as }

  it "the tree is present on the board" do
    get root_path

    assert_select "aside.rail"
    assert_select ".rail .row--folder .row__label", text: folders(:owner_books).name
  end

  it "the tree is present on a note's full pane too" do
    get note_path(notes(:owner_plain))

    assert_select "aside.rail"
  end

  it "a note row opens the note full-pane, not a modal" do
    get root_path

    assert_select ".rail a.row--note[href=?]", note_path(notes(:owner_pinned))
    assert_select ".rail a.row--note[data-turbo-frame]", count: 0
  end

  it "unfiled notes sit at the root of the tree" do
    get root_path

    assert_select ".rail__root-notes[data-folder-id=''] a.row--root[href=?]", note_path(notes(:owner_plain))
  end

  it "an untitled note row shows its first line only" do
    get root_path

    assert_select ".rail a.row--note[href=?] .row__label", note_path(notes(:owner_untitled)),
      text: "the way sound carries over water"

    assert_select ".rail .row__label", text: /and a second line/, count: 0
  end

  it "an empty folder still renders as a blank drop target" do
    get root_path

    assert_select "##{dom_id(folders(:owner_empty), :notes)}"
    assert_select "##{dom_id(folders(:owner_empty), :notes)} .rail__empty", count: 0
  end

  it "no other account's folders or notes reach the tree" do
    get root_path

    assert_select ".rail", text: /Someone else's note/, count: 0
    expect(response.body).not_to match(/LEAK CANARY/)
  end

  it "the folder name breaks out of the row's frame" do
    get root_path

    assert_select ".row--folder a.row__label[data-turbo-frame=?]", "_top"
    assert_select ".row--folder a.row__edit[data-turbo-frame]", count: 0
  end

  it "does not show folder note counts" do
    get root_path

    assert_select ".row__count", count: 0
  end

  it "folder rows accept a drag on entry, not only on hover" do
    get root_path

    assert_select ".row--folder[data-action*=?]", "dragenter->filing#over"
  end

  it "the folder being viewed is marked in the tree" do
    get folder_path(folders(:owner_books))

    assert_select ".row--folder[aria-current=true] .row__label", text: folders(:owner_books).name
  end

  it "the note being viewed is marked in the tree" do
    get note_path(notes(:owner_pinned))

    assert_select "a.row--note[aria-current=true][href=?]", note_path(notes(:owner_pinned))
  end

  it "the board marks itself when no folder is open" do
    get root_path

    assert_select ".row--view[aria-current=page] .row__label", text: "Notes"
  end

  it "cards and note rows are draggable filing sources" do
    get root_path

    assert_select "article.card[draggable=true][data-note-url=?][data-folder-id='']", api_v1_note_path(notes(:owner_plain))
    assert_select "article.card a.card__open[draggable=false]"
    assert_select ".rail a.row--note[draggable=true][data-note-url=?]", api_v1_note_path(notes(:owner_plain))
    assert_select ".row--folder[draggable=true][data-folder-id=?][data-folder-url=?]", folders(:owner_books).id.to_s, api_v1_folder_path(folders(:owner_books))
    assert_select ".shell[data-controller~=?]", "filing"
  end

  it "note rows are drop targets for manual ordering" do
    get root_path

    assert_select ".rail a.row--note[data-action*=?]", "drop->filing#drop"
  end

  it "the Notes row is a drop target that unfiles" do
    get root_path

    assert_select ".row--view[data-folder-id='']"
  end
end
