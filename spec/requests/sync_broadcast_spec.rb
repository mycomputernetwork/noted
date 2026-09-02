require "rails_helper"

RSpec.describe "sync broadcasts", type: :request do
  let(:note) { notes(:owner_plain) }

  before { sign_in_as }

  it "carries the tab that made the write, so that tab can ignore its own echo" do
    expect {
      patch api_v1_note_path(note), params: { note: { body: "Rewritten" } },
            headers: { "X-Client-Id" => "tab-1" }
    }.to have_broadcasted_to(owner).from_channel(SyncChannel)
      .with(hash_including("client" => "tab-1", "id" => note.id))
  end

  it "carries no tab for a client that sends no id" do
    expect {
      patch api_v1_note_path(note), params: { note: { body: "From Android" } },
            headers: bearer_headers
    }.to have_broadcasted_to(owner).from_channel(SyncChannel)
      .with(hash_including("client" => nil))
  end
end
