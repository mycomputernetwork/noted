require "rails_helper"

RSpec.describe "notes board", type: :request do
  it "the board renders kept notes" do
    get root_path

    assert_response :success
    assert_select ".card", minimum: 2
    assert_match notes(:owner_plain).title, response.body
  end

  it "archived and trashed notes stay off the board" do
    get root_path

    expect(response.body).not_to match(notes(:owner_archived).title)
    expect(response.body).not_to match(notes(:owner_trashed).title)
  end

  it "no other account's content reaches the board" do
    get root_path

    expect(response.body).not_to match(notes(:other_note).title)
    expect(response.body).not_to match(/LEAK CANARY/)
  end

  it "pinned notes render in their own section above the rest" do
    get root_path

    assert_select ".board__section:first-of-type .board__heading", "Pinned"
    expect(board_titles.index(notes(:owner_pinned).title))
      .to be < board_titles.index(notes(:owner_plain).title)
  end

  it "the pinned section is absent when nothing is pinned" do
    notes(:owner_pinned).update!(pinned: false)

    get root_path

    assert_select ".board__heading", "Notes"
    assert_select ".board__heading", { text: "Pinned", count: 0 }
  end

  it "sorting defaults to last edited, newest first" do
    older = owner.notes.create!(title: "Older edit", body: "x", updated_at: 2.days.ago)
    newer = owner.notes.create!(title: "Newer edit", body: "x", updated_at: 1.minute.ago)

    get root_path

    expect(board_titles.index(newer.title)).to be < board_titles.index(older.title)
  end

  it "direction reverses the order" do
    older = owner.notes.create!(title: "Older edit", body: "x", updated_at: 2.days.ago)
    newer = owner.notes.create!(title: "Newer edit", body: "x", updated_at: 1.minute.ago)

    get root_path(direction: "asc")

    expect(board_titles.index(older.title)).to be < board_titles.index(newer.title)
  end

  it "sorting by creation orders independently of edits" do
    first  = owner.notes.create!(title: "Created first",  body: "x", created_at: 3.days.ago, updated_at: 1.minute.ago)
    second = owner.notes.create!(title: "Created second", body: "x", created_at: 1.hour.ago, updated_at: 2.days.ago)

    get root_path(sort: "created")

    expect(board_titles.index(second.title)).to be < board_titles.index(first.title)
  end

  it "an unknown sort key falls back to last edited rather than erroring" do
    get root_path(sort: "'; drop table notes; --", direction: "sideways")

    assert_response :success
    assert_select ".sort__option[aria-current=true]", "Edited"
  end

  it "an empty board explains itself" do
    owner.notes.destroy_all

    get root_path

    assert_response :success
    assert_select ".empty__title"
    assert_select ".card", count: 0
  end

  it "an untitled note still renders a card" do
    owner.notes.create!(title: nil, body: "a fragment with no title")

    get root_path

    assert_match "a fragment with no title", response.body
  end

  it "the health check answers without a session" do
    get rails_health_check_path

    assert_response :success
  end
end
