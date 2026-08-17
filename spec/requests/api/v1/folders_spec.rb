require "swagger_helper"

RSpec.describe "api/v1/folders", type: :request do
  let(:owner) { users(:owner) }
  let(:owner_books) { folders(:owner_books) }
  let(:owner_groceries) { folders(:owner_groceries) }
  let(:other_books) { folders(:other_books) }

  path "/api/v1/folders" do
    get "lists folders" do
      tags "Folders"
      description "Returns every folder for the current account, ordered by position."
      produces "application/json"

      response "200", "folders in position order" do
        schema type: :array, items: { "$ref" => "#/components/schemas/Folder" }
        run_test! do
          ids = response.parsed_body.map { |folder| folder["id"] }
          expect(ids).to include(owner_books.id, owner_groceries.id)
          expect(ids).not_to include(other_books.id)
        end
      end
    end

    post "creates a folder" do
      tags "Folders"
      description "Creates a folder. Supply `id` to reuse a client-generated UUIDv7 for offline sync; omit it to have the server assign one."
      consumes "application/x-www-form-urlencoded"
      produces "application/json"
      parameter name: :folder, in: :formData, schema: {
        type: :object,
        properties: {
          folder: {
            type: :object,
            properties: {
              name: { type: :string, description: "Display name. Required and must be non-blank.", example: "Recipes" },
              id: { type: :string, format: :uuid, description: "Optional client-supplied UUIDv7.", example: "018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d2" }
            },
            required: ["name"]
          }
        },
        required: ["folder"]
      }

      response "201", "created" do
        schema "$ref" => "#/components/schemas/Folder"
        let(:folder) { { name: "Recipes" } }

        run_test! do
          expect(response.parsed_body["name"]).to eq("Recipes")
          expect(owner.folders.find(response.parsed_body["id"])).to be_present
        end
      end

      response "201", "created with client-supplied UUID" do
        schema "$ref" => "#/components/schemas/Folder"
        let(:client_id) { SecureRandom.uuid }
        let(:folder) { { id: client_id, name: "Offline" } }

        run_test! do
          expect(response.parsed_body["id"]).to eq(client_id)
        end
      end

      response "422", "blank name" do
        schema "$ref" => "#/components/schemas/Errors"
        let(:folder) { { name: "" } }
        run_test!
      end
    end
  end

  path "/api/v1/folders/{id}" do
    parameter name: :id, in: :path, type: :string

    get "shows a folder" do
      tags "Folders"
      description "Returns a single folder owned by the current account."
      produces "application/json"

      response "200", "found" do
        schema "$ref" => "#/components/schemas/Folder"
        let(:id) { owner_books.id }

        run_test! do
          expect(response.parsed_body).to include("id" => owner_books.id, "name" => owner_books.name)
        end
      end

      response "404", "unknown or other account" do
        let(:id) { other_books.id }
        run_test!
      end
    end

    patch "updates a folder" do
      tags "Folders"
      description "Renames or reorders a folder. Set `position` to move it within the account's ordering."
      consumes "application/x-www-form-urlencoded"
      produces "application/json"
      parameter name: :folder, in: :formData, schema: {
        type: :object,
        properties: {
          folder: {
            type: :object,
            properties: {
              name: { type: :string, description: "New display name. Required and must be non-blank.", example: "Books renamed" },
              position: { type: :integer, description: "New sort position within the account.", example: 1 }
            },
            required: ["name"]
          }
        },
        required: ["folder"]
      }

      response "200", "updated" do
        schema "$ref" => "#/components/schemas/Folder"
        let(:id) { owner_books.id }
        let(:folder) { { name: "Books renamed" } }

        run_test! do
          expect(owner_books.reload.name).to eq("Books renamed")
        end
      end

      response "404", "other account folder" do
        let(:id) { other_books.id }
        let(:folder) { { name: "stolen" } }
        run_test!
      end
    end

    delete "deletes a folder" do
      tags "Folders"
      description "Tombstones a folder (soft delete). Its notes are kept and become unfiled (`folder_id` set to null)."
      produces "application/json"

      response "204", "deleted, its notes unfiled" do
        let(:id) { owner_books.id }

        run_test! do
          expect(owner_books.reload.deleted_at).to be_present
          expect(notes(:owner_pinned).reload.folder_id).to be_nil
        end
      end

      response "404", "other account folder" do
        let(:id) { other_books.id }
        run_test!
      end
    end
  end
end
