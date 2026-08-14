class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      # index: false because every index below leads with user_id, so a
      # standalone one would be redundant. Ownership is still enforced by the
      # foreign key and by the fact that nothing is ever loaded outside
      # current_user.
      t.references :user, null: false, foreign_key: true, index: false

      t.string :title
      t.text :body, null: false, default: ""

      # A note is in zero or one folder. Deleting a folder nullifies this
      # rather than cascading — the notes become unfiled.
      t.references :folder, null: true, foreign_key: { on_delete: :nullify }, index: false

      t.boolean :pinned, null: false, default: false
      t.datetime :archived_at
      t.datetime :deleted_at

      t.timestamps
    end

    # Notes are NOT dateable. Anything that belongs to a day is a day_entry or
    # the day's log — see the next two migrations. There is deliberately no
    # entry_date column here and no path that would put a note on the calendar.

    # Tiled board: PINNED / OTHERS split, then last edited or date created.
    add_index :notes, [ :user_id, :pinned, :updated_at ]
    add_index :notes, [ :user_id, :created_at ]

    # Folder view.
    add_index :notes, [ :user_id, :folder_id ]

    # Archive and trash boards, and the 30-day purge sweep.
    add_index :notes, [ :user_id, :archived_at ]
    add_index :notes, [ :user_id, :deleted_at ]
  end
end
