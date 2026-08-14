require "test_helper"

# Folders (PRD §5) and the board filtered to one (§7.3), created, renamed and
# deleted from the sidebar.
class FoldersControllerTest < ActionDispatch::IntegrationTest
  # --- The folder board ----------------------------------------------------

  test "a folder board is the board, filtered" do
    get folder_path(folders(:owner_books))

    assert_response :success
    assert_select ".board__title", folders(:owner_books).name

    # The board is filtered; the tree beside it is not, and must not be —
    # every note stays reachable from the sidebar whatever board is open.
    assert_equal [ notes(:owner_pinned).title ], board_titles
    assert_select ".rail .row__label", text: notes(:owner_plain).tree_label
  end

  test "a folder board keeps the composer, and a note written there lands there" do
    get folder_path(folders(:owner_books))

    assert_select "a.composer[href=?]", new_note_path(folder_id: folders(:owner_books).id)
  end

  test "sorting on a folder board stays on the folder" do
    get folder_path(folders(:owner_books))

    assert_select ".sort__option[href=?]", folder_path(folders(:owner_books), sort: "created", direction: "desc")
  end

  test "an empty folder board says so rather than looking broken" do
    get folder_path(folders(:owner_empty))

    assert_response :success
    assert_select ".empty__title", /Packing/
  end

  test "another account's folder has no board" do
    get folder_path(folders(:other_books))

    assert_response :not_found
  end

  # --- Create --------------------------------------------------------------

  test "a folder is created from the sidebar" do
    assert_difference -> { owner.folders.count }, 1 do
      post folders_path, params: { folder: { name: "Recipes" } }
    end

    assert_redirected_to folder_path(owner.folders.find_by(name: "Recipes"))
  end

  test "a created folder belongs to the current account" do
    post folders_path, params: { folder: { name: "Recipes" } }

    assert_equal owner, Folder.find_by(name: "Recipes").user
  end

  test "a duplicate name is refused and said out loud" do
    assert_no_difference -> { Folder.count } do
      post folders_path, params: { folder: { name: folders(:owner_books).name.downcase } }
    end

    assert_match(/already exists/, flash[:alert])
  end

  # Names are unique per user, not globally (PRD §5).
  test "a name another account already uses is fine" do
    other.folders.create!(name: "Recipes")

    assert_difference -> { owner.folders.count }, 1 do
      post folders_path, params: { folder: { name: "Recipes" } }
    end
  end

  # --- Rename --------------------------------------------------------------

  test "the row swaps for a form in place" do
    get edit_folder_path(folders(:owner_books)), headers: { "Turbo-Frame" => dom_id(folders(:owner_books), :row) }

    assert_response :success
    assert_select "turbo-frame##{dom_id(folders(:owner_books), :row)} input[name=?]", "folder[name]"
  end

  test "renaming keeps the folder's notes" do
    folder = folders(:owner_books)

    patch folder_path(folder), params: { folder: { name: "Reading" } }

    assert_redirected_to folder_path(folder)
    assert_equal "Reading", folder.reload.name
    assert_equal 1, folder.notes.count
  end

  test "another account's folder cannot be renamed" do
    patch folder_path(folders(:other_books)), params: { folder: { name: "Hijacked" } }

    assert_response :not_found
    assert_equal "Books", folders(:other_books).reload.name
  end

  # --- Delete --------------------------------------------------------------

  # Deleting a folder is not a way to delete notes, and there is deliberately
  # no way to make it one (PRD §11).
  test "deleting a folder unfiles its notes rather than destroying them" do
    note = notes(:owner_pinned)

    assert_no_difference -> { Note.count } do
      delete folder_path(folders(:owner_books))
    end

    assert_redirected_to root_path
    assert_nil note.reload.folder_id
    assert_predicate note, :persisted?
  end

  test "another account's folder cannot be deleted" do
    assert_no_difference -> { Folder.count } do
      delete folder_path(folders(:other_books))
    end

    assert_response :not_found
  end
end
