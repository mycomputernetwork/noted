require "swagger_helper"

RSpec.describe "api/v1/notes", type: :request do
  let(:Authorization) { bearer_headers["Authorization"] }
  let(:note) { { note: { title: "Anything" } } }
  let(:id) { owner_plain.id }
  let(:owner_plain) { notes(:owner_plain) }
  let(:owner_pinned) { notes(:owner_pinned) }
  let(:other_note) { notes(:other_note) }
  let(:owner_groceries) { folders(:owner_groceries) }
  let(:other_books) { folders(:other_books) }

  path "/api/v1/notes" do
    get "lists kept notes" do
      tags "Notes"
      security [ { bearerAuth: [] } ]
      description "Returns kept notes for the current account in board order. Pinned and unpinned notes are separate zones. Archived and trashed notes are excluded."
      produces "application/json"

      response "200", "kept notes, ordered" do
        schema type: :array, items: { "$ref" => "#/components/schemas/Note" }
        run_test! do
          ids = response.parsed_body.map { |note| note["id"] }
          expect(ids).to include(owner_plain.id)
          expect(ids).not_to include(notes(:owner_archived).id, notes(:owner_trashed).id, other_note.id)
          expect(response.body).not_to include("LEAK CANARY")
        end
      end

      response "401", "the access token is missing, expired, or issued for another audience" do
        let(:Authorization) { nil }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end

    post "creates a note" do
      tags "Notes"
      security [ { bearerAuth: [] } ]
      description "Creates a note. The title is derived from the first line of `body`. Supply `id` to reuse a client-generated UUIDv7 for offline sync. `folder_id` must belong to the current account."
      consumes "application/x-www-form-urlencoded"
      produces "application/json"
      parameter name: :note, in: :formData, schema: {
        type: :object,
        properties: {
          note: {
            type: :object,
            properties: {
              body: { type: :string, description: "Note text. Required; its first line becomes the title.", example: "Groceries\nBuy milk" },
              id: { type: :string, format: :uuid, description: "Optional client-supplied UUIDv7.", example: "018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d2" },
              folder_id: { type: :string, format: :uuid, description: "Optional owning folder; must belong to the current account.", example: "018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d3" },
              board_position: { type: :integer, description: "Optional All Notes masonry order. Omit it to place the note before the current board.", example: 0 },
              folder_board_position: { type: :integer, description: "Optional masonry order inside the note's folder. Omit it to place the note before that folder board.", example: 0 }
            },
            required: ["body"]
          }
        },
        required: ["note"]
      }

      response "201", "created" do
        schema "$ref" => "#/components/schemas/Note"
        let(:note) { { body: "m" } }

        run_test! do
          body = response.parsed_body
          expect(body["body"]).to eq("m")
          expect(body["url"]).to eq(api_v1_note_path(body["id"]))
          expect(body["html_url"]).to eq(note_path(body["id"]))
        end
      end

      response "201", "created with client-supplied UUID" do
        schema "$ref" => "#/components/schemas/Note"
        let(:client_id) { SecureRandom.uuid }
        let(:note) { { id: client_id, body: "offline" } }

        run_test! do
          expect(response.parsed_body["id"]).to eq(client_id)
        end
      end

      response "422", "folder belongs to another account" do
        schema "$ref" => "#/components/schemas/Errors"
        let(:note) { { body: "x", folder_id: other_books.id } }

        run_test!
      end

      response "401", "the access token is missing, expired, or issued for another audience" do
        let(:Authorization) { nil }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end

  path "/api/v1/notes/reorder" do
    patch "reorders the masonry board" do
      tags "Notes"
      security [ { bearerAuth: [] } ]
      description "Replaces the current account's board order with the submitted visible note ids. Pass `folder_id` when reordering a folder board. Pinned and unpinned notes remain separate display zones."
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          note_ids: {
            type: :array,
            description: "Every visible note id in the board's new order.",
            items: { type: :string, format: :uuid }
          },
          folder_id: {
            type: :string,
            nullable: true,
            description: "Folder being viewed, or null on the all-notes board."
          }
        },
        required: [ "note_ids" ]
      }

      response "200", "board reordered" do
        schema type: :array, items: { "$ref" => "#/components/schemas/Note" }

        context "with the all-notes board" do
          let(:a) { owner.notes.create!(title: "Board A", body: "x", board_position: 10) }
          let(:b) { owner.notes.create!(title: "Board B", body: "x", board_position: 11) }
          let(:payload) do
            ids = owner.notes.kept.board_order.map(&:id)
            pinned_ids = owner.notes.kept.where(pinned: true).board_order.map(&:id)
            { note_ids: [ *pinned_ids, b.id, a.id, *(ids - pinned_ids - [ a.id, b.id ]) ] }
          end

          run_test! do
            expect(owner.notes.kept.where(pinned: false).board_order.first(2).map(&:id)).to eq([ b.id, a.id ])
          end
        end

        context "with a folder board" do
          let(:folder) { folders(:owner_books) }
          let(:a) { owner.notes.create!(title: "Folder A", body: "x", folder: folder, board_position: 20, folder_board_position: 20) }
          let(:b) { owner.notes.create!(title: "Folder B", body: "x", folder: folder, board_position: 21, folder_board_position: 21) }
          let(:payload) { { folder_id: folder.id, note_ids: [ owner_pinned.id, b.id, a.id ] } }

          run_test! do
            expect(owner.notes.kept.where(folder: folder, pinned: false).folder_board_order.first(2).map(&:id)).to eq([ b.id, a.id ])
            expect(a.reload.board_position).to eq(20)
            expect(a.folder_board_position).to be > b.reload.folder_board_position
          end
        end
      end

      response "422", "invalid board reorder" do
        schema "$ref" => "#/components/schemas/Errors"

        context "when a visible note is missing" do
          let(:payload) { { note_ids: [ owner_plain.id ] } }

          run_test!
        end

        context "when the folder belongs to another account" do
          let(:payload) { { folder_id: other_books.id, note_ids: [ owner_plain.id ] } }

          run_test!
        end
      end

      response "401", "the access token is missing, expired, or issued for another audience" do
        let(:Authorization) { nil }
        let(:payload) { { note_ids: [ owner_plain.id ] } }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end

  path "/api/v1/notes/{id}" do
    parameter name: :id, in: :path, type: :string

    get "shows a note" do
      tags "Notes"
      security [ { bearerAuth: [] } ]
      description "Returns a single kept note owned by the current account."
      produces "application/json"

      response "200", "found" do
        schema "$ref" => "#/components/schemas/Note"
        let(:id) { owner_plain.id }

        run_test! do
          expect(response.parsed_body).to include(
            "id" => owner_plain.id,
            "title" => owner_plain.title,
            "folder_id" => owner_plain.folder_id,
            "images" => []
          )
        end
      end

      response "404", "unknown or other account" do
        schema "$ref" => "#/components/schemas/Error"
        let(:id) { other_note.id }
        run_test!
      end

      response "401", "the access token is missing, expired, or issued for another audience" do
        let(:Authorization) { nil }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end

    patch "updates a note" do
      tags "Notes"
      security [ { bearerAuth: [] } ]
      description "Updates a note. Send only the fields to change. Pass an empty `folder_id` to unfile the note; a `folder_id` from another account is rejected with 422. When `folder_id` changes, the note moves to the top of that sidebar list unless `before_id` or `after_id` names an exact insert target."
      consumes "application/x-www-form-urlencoded"
      produces "application/json"
      parameter name: :note, in: :formData, schema: {
        type: :object,
        properties: {
          note: {
            type: :object,
            properties: {
              title: { type: :string, description: "Override the derived title.", example: "Groceries" },
              body: { type: :string, description: "Replacement note text.", example: "Groceries\nBuy milk" },
              folder_id: { type: :string, description: "Move to this folder, or empty string to unfile. Must belong to the current account.", example: "018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d3" },
              before_id: { type: :string, description: "Insert before this note in the destination sidebar list.", example: "018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d4" },
              after_id: { type: :string, description: "Insert after this note in the destination sidebar list.", example: "018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d5" },
              board_position: { type: :integer, description: "All Notes masonry order. Prefer `/api/v1/notes/reorder` when moving more than one note.", example: 0 },
              folder_board_position: { type: :integer, description: "Folder masonry order inside the current folder. Prefer `/api/v1/notes/reorder` when moving more than one note.", example: 0 },
              pinned: { type: :boolean, description: "Pin or unpin the note.", example: true }
            }
          }
        }
      }

      response "200", "updated" do
        schema "$ref" => "#/components/schemas/Note"
        let(:id) { owner_plain.id }
        let(:note) do
          {
            title: "Renamed",
            body: "rewritten",
            folder_id: owner_groceries.id,
            pinned: "1"
          }
        end

        run_test! do
          owner_plain.reload
          expect(owner_plain.title).to eq("Renamed")
          expect(owner_plain.folder).to eq(owner_groceries)
          expect(owner_plain).to be_pinned
        end
      end

      response "200", "unfiled" do
        schema "$ref" => "#/components/schemas/Note"
        let(:id) { owner_pinned.id }
        let(:note) { { folder_id: "" } }

        run_test! do
          expect(owner_pinned.reload.folder_id).to be_nil
          expect(owner_pinned.position).to eq(0)
        end
      end

      response "200", "filed at top" do
        schema "$ref" => "#/components/schemas/Note"
        let(:id) { owner_plain.id }
        let(:note) { { folder_id: owner_groceries.id } }

        run_test! do
          expect(owner_plain.reload.folder).to eq(owner_groceries)
          expect(owner_plain.position).to eq(0)
        end
      end

      response "200", "moved before another note" do
        schema "$ref" => "#/components/schemas/Note"
        let(:target) { owner.notes.create!(title: "Target", body: "x", folder: owner_groceries) }
        let(:id) { owner_plain.id }
        let(:note) { { folder_id: owner_groceries.id, before_id: target.id } }

        run_test! do
          branch = Tree.for(user: owner).branch_for(owner_groceries)
          expect(branch.notes.map(&:id).first(2)).to eq([ owner_plain.id, target.id ])
        end
      end

      response "404", "other account note" do
        schema "$ref" => "#/components/schemas/Error"
        let(:id) { other_note.id }
        let(:note) { { body: "overwritten" } }

        run_test! do
          expect(other_note.reload.body).to eq("must never appear in owner's queries")
        end
      end

      response "422", "folder belongs to another account" do
        schema "$ref" => "#/components/schemas/Errors"
        let(:id) { owner_plain.id }
        let(:note) { { folder_id: other_books.id } }

        run_test! do
          expect(owner_plain.reload.folder_id).to be_nil
        end
      end

      response "422", "insert target belongs to another account" do
        schema "$ref" => "#/components/schemas/Errors"
        let(:id) { owner_plain.id }
        let(:note) { { folder_id: "", before_id: other_note.id } }

        run_test! do
          expect(owner_plain.reload.folder_id).to be_nil
        end
      end

      response "401", "the access token is missing, expired, or issued for another audience" do
        let(:Authorization) { nil }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end

    delete "discards an empty note" do
      tags "Notes"
      security [ { bearerAuth: [] } ]
      description "Permanently deletes a note only when it is empty (blank title and body). A note with content returns 422; use archive or trash instead."
      produces "application/json"

      response "204", "discarded" do
        let(:empty_note) { users(:owner).notes.create!(title: "", body: "") }
        let(:id) { empty_note.id }

        run_test! do
          expect(Note.exists?(empty_note.id)).to be(false)
        end
      end

      response "422", "not empty" do
        schema "$ref" => "#/components/schemas/Errors"
        let(:id) { owner_plain.id }
        run_test!
      end

      response "404", "other account note" do
        schema "$ref" => "#/components/schemas/Error"
        let(:id) { other_note.id }
        run_test!
      end

      response "401", "the access token is missing, expired, or issued for another audience" do
        let(:Authorization) { nil }
        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end
end
