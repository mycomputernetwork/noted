require "rails_helper"

RSpec.describe "folders", type: :request do
  before { sign_in_as }

  it "a folder board is the board, filtered" do
    get folder_path(folders(:owner_books))

    assert_response :success
    assert_select ".board__title", folders(:owner_books).name

    assert_equal [ notes(:owner_pinned).title ], board_titles
    assert_select ".rail .row__label", text: notes(:owner_plain).tree_label
  end

  it "a folder board keeps the composer, and a note written there lands there" do
    get folder_path(folders(:owner_books))

    assert_select "a.composer[href=?]", new_note_path(folder_id: folders(:owner_books).id)
  end

  it "sorting on a folder board stays on the folder" do
    get folder_path(folders(:owner_books))

    assert_select ".sort__option[href=?]", folder_path(folders(:owner_books), sort: "created", direction: "desc")
  end

  it "an empty folder board says so rather than looking broken" do
    get folder_path(folders(:owner_empty))

    assert_response :success
    assert_select ".empty__title", /Packing/
  end

  it "another account's folder has no board" do
    get folder_path(folders(:other_books))

    assert_response :not_found
  end

  it "a folder is created from the sidebar" do
    expect { post folders_path, params: { folder: { name: "Recipes" } } }
      .to change { owner.folders.count }.by(1)

    assert_redirected_to folder_path(owner.folders.find_by(name: "Recipes"))
  end

  it "a created folder belongs to the current account" do
    post folders_path, params: { folder: { name: "Recipes" } }

    assert_equal owner, Folder.find_by(name: "Recipes").user
  end

  it "a duplicate name is allowed" do
    expect { post folders_path, params: { folder: { name: folders(:owner_books).name.downcase } } }
      .to change { owner.folders.count }.by(1)
  end

  it "a name another account already uses is fine" do
    other.folders.create!(name: "Recipes")

    expect { post folders_path, params: { folder: { name: "Recipes" } } }
      .to change { owner.folders.count }.by(1)
  end

  it "the row swaps for a form in place" do
    get edit_folder_path(folders(:owner_books)), headers: { "Turbo-Frame" => dom_id(folders(:owner_books), :row) }

    assert_response :success
    assert_select "turbo-frame##{dom_id(folders(:owner_books), :row)} input[name=?]", "folder[name]"
  end

  it "renaming keeps the folder's notes" do
    folder = folders(:owner_books)

    patch folder_path(folder), params: { folder: { name: "Reading" } }

    assert_redirected_to folder_path(folder)
    assert_equal "Reading", folder.reload.name
    assert_equal 1, folder.notes.count
  end

  it "another account's folder cannot be renamed" do
    patch folder_path(folders(:other_books)), params: { folder: { name: "Hijacked" } }

    assert_response :not_found
    assert_equal "Books", folders(:other_books).reload.name
  end

  it "deleting a folder unfiles its notes rather than destroying them" do
    note = notes(:owner_pinned)

    expect { delete folder_path(folders(:owner_books)) }.not_to change { Note.count }

    assert_redirected_to root_path
    expect(note.reload.folder_id).to be_nil
    expect(note).to be_persisted
  end

  it "another account's folder cannot be deleted" do
    expect { delete folder_path(folders(:other_books)) }.not_to change { Folder.count }

    assert_response :not_found
  end
end
