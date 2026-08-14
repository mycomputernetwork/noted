require "test_helper"

# The sidebar tree as rendered (PRD §7.6). It is in the layout, so it is on
# every view — which is what most of these assert.
class SidebarTest < ActionDispatch::IntegrationTest
  test "the tree is present on the board" do
    get root_path

    assert_select "aside.rail"
    assert_select ".rail .row--folder .row__label", text: folders(:owner_books).name
  end

  test "the tree is present on a note's full pane too" do
    get note_path(notes(:owner_plain))

    assert_select "aside.rail"
  end

  test "a note row opens the note full-pane, not a modal" do
    get root_path

    assert_select ".rail a.row--note[href=?]", note_path(notes(:owner_pinned))
    assert_select ".rail a.row--note[data-turbo-frame]", count: 0
  end

  test "unfiled notes sit at the root of the tree" do
    get root_path

    assert_select ".rail a.row--root[href=?]", note_path(notes(:owner_plain))
  end

  test "an untitled note row shows its first line only" do
    get root_path

    assert_select ".rail .row--untitled .row__label", text: "the way sound carries over water"

    # The card on the board shows the whole body, and should. This is about
    # the row: one line, never two (PRD §7.6).
    assert_select ".rail .row__label", text: /and a second line/, count: 0
  end

  test "an empty folder still renders, with something to say" do
    get root_path

    assert_select "##{dom_id(folders(:owner_empty), :notes)} .rail__empty"
  end

  test "no other account's folders or notes reach the tree" do
    get root_path

    assert_select ".rail", text: /Someone else's note/, count: 0
    assert_no_match(/LEAK CANARY/, response.body)
  end

  # The sidebar always shows where you are (PRD §7.6).
  test "the folder being viewed is marked in the tree" do
    get folder_path(folders(:owner_books))

    assert_select ".row--folder[aria-current=true] .row__label", text: folders(:owner_books).name
  end

  test "the note being viewed is marked in the tree" do
    get note_path(notes(:owner_pinned))

    assert_select "a.row--note[aria-current=true][href=?]", note_path(notes(:owner_pinned))
  end

  test "the board marks itself when no folder is open" do
    get root_path

    assert_select ".row--view[aria-current=page] .row__label", text: "Notes"
  end

  # Cards are drag sources; folder rows are drop targets (PRD §11).
  test "cards are draggable and folder rows accept them" do
    get root_path

    assert_select "article.card[draggable=true][data-note-url=?]", note_path(notes(:owner_plain))
    assert_select ".row--folder[data-folder-id=?]", folders(:owner_books).id.to_s
    assert_select ".shell[data-controller=?]", "filing"
  end

  # Dropping onto Notes unfiles, which needs no route of its own: filing is an
  # update to a note either way.
  test "the Notes row is a drop target that unfiles" do
    get root_path

    assert_select ".row--view[data-folder-id='']"
  end
end
