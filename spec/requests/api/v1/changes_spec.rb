require "swagger_helper"

RSpec.describe "api/v1/changes", type: :request do
  let(:owner) { users(:owner) }
  let(:owner_note) { notes(:owner_pinned) }
  let(:other_note) { notes(:other_note) }

  path "/api/v1/changes" do
    get "lists changes since a cursor" do
      tags "Changes"
      description "Delta sync feed: notes and folders changed after the cursor, tombstones included. Omit the cursor for a full snapshot. Pass the returned `cursor` back on the next request."
      produces "application/json"
      parameter name: :cursor, in: :query, required: false, schema: { type: :string, format: :"date-time" },
                description: "Opaque cursor from a previous response. Omit for a full snapshot."

      response "200", "changed rows and a new cursor" do
        let(:cursor) { nil }
        schema "$ref" => "#/components/schemas/Changes"
        run_test! do
          ids = response.parsed_body["notes"].map { |n| n["id"] }
          expect(ids).to include(owner_note.id)
          expect(ids).not_to include(other_note.id)
          expect(response.parsed_body["cursor"]).to be_present
        end
      end

      response "200", "only rows changed after the cursor" do
        let(:cursor) { 10.years.from_now.utc.iso8601 }
        schema "$ref" => "#/components/schemas/Changes"
        run_test! do
          expect(response.parsed_body["notes"]).to be_empty
          expect(response.parsed_body["folders"]).to be_empty
        end
      end
    end
  end
end
