class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes, id: :string do |t|
      # index: false — every index below leads with user_id, so a standalone
      # one would be redundant.
      t.references :user, null: false, foreign_key: true, index: false, type: :string

      t.string :title
      t.text :body, null: false, default: ""

      t.references :folder, type: :string, null: true,
        foreign_key: { on_delete: :nullify }, index: false

      t.boolean :pinned, null: false, default: false
      t.datetime :archived_at
      t.datetime :deleted_at

      t.timestamps
    end

    # Notes are not dateable — no entry_date column, no path onto the calendar.
    add_index :notes, [ :user_id, :pinned, :updated_at ]
    add_index :notes, [ :user_id, :created_at ]
    add_index :notes, [ :user_id, :folder_id ]
    add_index :notes, [ :user_id, :archived_at ]
    add_index :notes, [ :user_id, :deleted_at ]
  end
end
