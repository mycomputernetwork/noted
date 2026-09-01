# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_01_090000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "day_entries", id: :string, force: :cascade do |t|
    t.text "body", default: "", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.datetime "deleted_at"
    t.string "kind", null: false
    t.integer "position", default: 0, null: false
    t.integer "start_minute"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id", "date", "kind", "start_minute", "position"], name: "index_day_entries_on_day_ordering"
    t.index ["user_id", "date"], name: "index_day_entries_open_actions", where: "kind = 'action' AND completed_at IS NULL AND deleted_at IS NULL"
    t.index ["user_id", "deleted_at"], name: "index_day_entries_on_user_id_and_deleted_at"
    t.check_constraint "kind = 'action' OR completed_at IS NULL", name: "day_entries_completion_actions_only"
    t.check_constraint "kind = 'event' OR start_minute IS NULL", name: "day_entries_time_events_only"
    t.check_constraint "kind IN ('event', 'action')", name: "day_entries_kind_valid"
    t.check_constraint "start_minute IS NULL OR (start_minute >= 0 AND start_minute <= 1439)", name: "day_entries_start_minute_range"
  end

  create_table "day_logs", id: :string, force: :cascade do |t|
    t.text "body", default: "", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id", "date"], name: "index_day_logs_on_user_id_and_date", unique: true
  end

  create_table "folders", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id", "deleted_at"], name: "index_folders_on_user_id_and_deleted_at"
    t.index ["user_id", "position"], name: "index_folders_on_user_id_and_position"
    t.index ["user_id", "updated_at"], name: "index_folders_on_user_id_and_updated_at"
  end

  create_table "notes", id: :string, force: :cascade do |t|
    t.datetime "archived_at"
    t.integer "board_position"
    t.text "body", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "folder_id"
    t.boolean "pinned", default: false, null: false
    t.integer "position"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id", "archived_at"], name: "index_notes_on_user_id_and_archived_at"
    t.index ["user_id", "board_position"], name: "index_notes_on_user_id_and_board_position"
    t.index ["user_id", "created_at"], name: "index_notes_on_user_id_and_created_at"
    t.index ["user_id", "deleted_at"], name: "index_notes_on_user_id_and_deleted_at"
    t.index ["user_id", "folder_id", "position"], name: "index_notes_on_tree_order"
    t.index ["user_id", "folder_id"], name: "index_notes_on_user_id_and_folder_id"
    t.index ["user_id", "pinned", "updated_at"], name: "index_notes_on_user_id_and_pinned_and_updated_at"
    t.index ["user_id", "updated_at"], name: "index_notes_on_user_id_and_updated_at"
  end

  create_table "sessions", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "id_token"
    t.string "ip_address"
    t.string "issuer"
    t.datetime "last_active_at", null: false
    t.string "sid"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.string "user_id", null: false
    t.index ["last_active_at"], name: "index_sessions_on_last_active_at"
    t.index ["sid"], name: "index_sessions_on_sid", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", id: :string, force: :cascade do |t|
    t.string "auth_sub"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["auth_sub"], name: "index_users_on_auth_sub", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "day_entries", "users"
  add_foreign_key "day_logs", "users"
  add_foreign_key "folders", "users"
  add_foreign_key "notes", "folders", on_delete: :nullify
  add_foreign_key "notes", "users"
  add_foreign_key "sessions", "users"
end
