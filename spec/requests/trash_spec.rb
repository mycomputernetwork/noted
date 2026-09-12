require "rails_helper"

RSpec.describe "trash", type: :request do
  before { sign_in_as }

  it "lists only the current account's trashed notes, newest deletion first" do
    newer = owner.notes.create!(title: "Newer trash", body: "mine", deleted_at: Time.current)
    other.notes.create!(title: "Foreign trash", body: "must not appear", deleted_at: Time.current)

    get trash_path

    assert_response :success
    assert_select "a.row[aria-current=page]", "Trash"
    assert_select ".trash-card[data-note-id=?]", notes(:owner_trashed).id
    assert_select ".trash-card", count: owner.notes.trashed.count
    expect(css_select(".trash-card").first["data-note-id"]).to eq(newer.id)
    assert_select ".trash-card[data-note-id=?]", notes(:owner_plain).id, count: 0
    expect(response.body).not_to include("Foreign trash")
  end

  it "offers restore, permanent deletion, and manual emptying" do
    get trash_path

    assert_select ".trash-card .card__select", count: 0
    assert_select ".trash-card button[data-action=?]", "trash#restore", text: "Restore"
    assert_select ".trash-card button[data-action=?]", "trash#purge", text: "Delete forever"
    assert_select "button[data-action=?]", "trash#empty", text: "Empty trash"
    assert_select "[data-trash-empty-url-value=?]", empty_trash_api_v1_notes_path
  end

  it "shows an empty state without an empty-trash control" do
    owner.notes.trashed.destroy_all

    get trash_path

    assert_select ".empty__title", "Trash is empty"
    assert_select "button[data-action=?]", "trash#empty", count: 0
  end
end
