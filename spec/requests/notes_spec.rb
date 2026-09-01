require "rails_helper"

RSpec.describe "notes board", type: :request do
  before { sign_in_as }

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

  it "orders cards by their board positions" do
    later = owner.notes.create!(title: "Later board card", body: "x", board_position: 20)
    sooner = owner.notes.create!(title: "Sooner board card", body: "x", board_position: 10)

    get root_path

    expect(board_titles.index(sooner.title)).to be < board_titles.index(later.title)
  end

  it "has no sort control" do
    get root_path(sort: "created", direction: "asc")

    assert_response :success
    assert_select ".sort", count: 0
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
