# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'API V1',
        version: 'v1',
        description: <<~DESC
          Notes and folders for the current account. Every request is scoped to
          the signed-in user; identifiers belonging to another account are
          reported as `404 Not Found` rather than `403` so their existence is
          not disclosed. Resource `id`s are UUIDv7 strings and may be supplied by
          the client on creation to support offline-first sync.
        DESC
      },
      paths: {},
      security: [ { bearerAuth: [] } ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: :JWT,
            description: 'An access token issued by the fleet auth service, verified against its JWKS. Tokens minted for the web client and for the native client are both accepted.'
          },
          idTokenAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: :JWT,
            description: 'An ID token from the same issuer. Only POST /api/v1/session takes one: it carries the email and name an account is created from.'
          }
        },
        schemas: {
          Error: {
            type: :object,
            description: 'A request that could not be served.',
            properties: {
              errors: { type: :array, description: 'One message per problem found.', items: { type: :string },
                        example: [ 'Not authenticated' ] }
            },
            required: %w[errors]
          },
          User: {
            type: :object,
            description: 'The account behind the presented token.',
            properties: {
              id: { type: :string, format: :uuid, description: 'UUIDv7 identifier.',
                    example: '018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d2' },
              email: { type: :string, format: :email, description: 'Email as auth holds it.', example: 'you@example.com' },
              name: { type: :string, nullable: true, description: 'Display name as auth holds it.', example: 'Prabhanshu Gupta' }
            },
            required: %w[id email name]
          },
          Folder: {
            type: :object,
            description: 'A folder groups notes for the current account.',
            properties: {
              id: { type: :string, format: :uuid, description: 'UUIDv7 identifier.',
                    example: '018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d2' },
              name: { type: :string, description: 'Display name.', example: 'Recipes' },
              position: { type: :integer, description: 'Sort order within the account, ascending.', example: 0 },
              deleted_at: { type: :string, format: :'date-time', nullable: true, description: 'Tombstone time, or null when live.' },
              created_at: { type: :string, format: :'date-time', nullable: true, description: 'ISO 8601 UTC creation time.' },
              updated_at: { type: :string, format: :'date-time', nullable: true, description: 'ISO 8601 UTC last-update time.' }
            },
            required: %w[id name position deleted_at created_at updated_at]
          },
          Note: {
            type: :object,
            description: 'A single note belonging to the current account.',
            properties: {
              id: { type: :string, format: :uuid, description: 'UUIDv7 identifier.',
                    example: '018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d2' },
              title: { type: :string, nullable: true, description: 'First line of the body, derived server-side.', example: 'Groceries' },
              body: { type: :string, nullable: true, description: 'Full note text.', example: "Groceries\nBuy milk" },
              folder_id: { type: :string, format: :uuid, nullable: true,
                           description: 'Owning folder, or null when unfiled.',
                           example: '018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d3' },
              pinned: { type: :boolean, description: 'Whether the note is pinned to the top of its list.', example: false },
              position: { type: :integer, nullable: true, description: 'Sidebar order within its folder or root list, ascending.', example: 0 },
              empty: { type: :boolean, description: 'True when title and body are both blank.', example: false },
              archived_at: { type: :string, format: :'date-time', nullable: true, description: 'Archive time, or null when kept.' },
              deleted_at: { type: :string, format: :'date-time', nullable: true, description: 'Trash time, or null when kept.' },
              created_at: { type: :string, format: :'date-time', nullable: true, description: 'ISO 8601 UTC creation time.' },
              updated_at: { type: :string, format: :'date-time', nullable: true, description: 'ISO 8601 UTC last-update time.' },
              url: { type: :string, description: 'API path for this note.', example: '/api/v1/notes/018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d2' },
              html_url: { type: :string, description: 'Web app path for this note.', example: '/notes/018f1c8e-7d7a-7a8f-b7ef-3dffdcf876d2' },
              images: {
                type: :array,
                description: 'Attached images. Currently always empty.',
                items: { type: :object }
              }
            },
            required: %w[id title body folder_id pinned position empty created_at updated_at url html_url images]
          },
          Changes: {
            type: :object,
            description: 'Delta since a cursor: rows changed after it, tombstones included. Omit the cursor for a full snapshot.',
            properties: {
              notes: { type: :array, description: 'Notes changed since the cursor.', items: { '$ref' => '#/components/schemas/Note' } },
              folders: { type: :array, description: 'Folders changed since the cursor.', items: { '$ref' => '#/components/schemas/Folder' } },
              cursor: { type: :string, format: :'date-time', description: 'Opaque cursor to pass as ?cursor= on the next request.' }
            },
            required: %w[notes folders cursor]
          },
          Errors: {
            type: :object,
            description: 'Validation failure. Each string is a human-readable message.',
            properties: {
              errors: {
                type: :array,
                items: { type: :string },
                example: ["Name can't be blank"]
              }
            },
            required: %w[errors]
          }
        }
      },
      servers: [
        {
          url: 'https://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'www.example.com'
            }
          }
        }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
