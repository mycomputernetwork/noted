require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  test "the board renders kept notes" do
    get root_path

    assert_response :success
    assert_select ".card", minimum: 2
    assert_match notes(:owner_plain).title, response.body
  end

  test "archived and trashed notes stay off the board" do
    get root_path

    assert_no_match notes(:owner_archived).title, response.body
    assert_no_match notes(:owner_trashed).title, response.body
  end

  test "no other account's content reaches the board" do
    get root_path

    assert_no_match notes(:other_note).title, response.body
    assert_no_match(/LEAK CANARY/, response.body)
  end

  test "pinned notes render in their own section above the rest" do
    get root_path

    assert_select ".board__section:first-of-type .board__heading", "Pinned"
    assert_operator board_titles.index(notes(:owner_pinned).title),
      :<, board_titles.index(notes(:owner_plain).title)
  end

  test "the pinned section is absent when nothing is pinned" do
    notes(:owner_pinned).update!(pinned: false)

    get root_path

    assert_select ".board__heading", "Notes"
    assert_select ".board__heading", { text: "Pinned", count: 0 }
  end

  test "sorting defaults to last edited, newest first" do
    older = owner.notes.create!(title: "Older edit", body: "x", updated_at: 2.days.ago)
    newer = owner.notes.create!(title: "Newer edit", body: "x", updated_at: 1.minute.ago)

    get root_path

    assert_operator board_titles.index(newer.title), :<, board_titles.index(older.title)
  end

  test "direction reverses the order" do
    older = owner.notes.create!(title: "Older edit", body: "x", updated_at: 2.days.ago)
    newer = owner.notes.create!(title: "Newer edit", body: "x", updated_at: 1.minute.ago)

    get root_path(direction: "asc")

    assert_operator board_titles.index(older.title), :<, board_titles.index(newer.title)
  end

  test "sorting by creation orders independently of edits" do
    first  = owner.notes.create!(title: "Created first",  body: "x", created_at: 3.days.ago, updated_at: 1.minute.ago)
    second = owner.notes.create!(title: "Created second", body: "x", created_at: 1.hour.ago, updated_at: 2.days.ago)

    get root_path(sort: "created")

    assert_operator board_titles.index(second.title), :<, board_titles.index(first.title)
  end

  test "an unknown sort key falls back to last edited rather than erroring" do
    get root_path(sort: "'; drop table notes; --", direction: "sideways")

    assert_response :success
    assert_select ".sort__option[aria-current=true]", "Edited"
  end

  test "an empty board explains itself" do
    owner.notes.destroy_all

    get root_path

    assert_response :success
    assert_select ".empty__title"
    assert_select ".card", count: 0
  end

  test "an untitled note still renders a card" do
    owner.notes.create!(title: nil, body: "a fragment with no title")

    get root_path

    assert_match "a fragment with no title", response.body
  end

  test "the health check answers without a session" do
    get rails_health_check_path

    assert_response :success
  end
end
