class CreateFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :folders do |t|
      t.references :user, null: false, foreign_key: true, index: false

      # Case is preserved as typed; the unique index below folds it.
      t.string :name, null: false

      # Manual ordering in the left rail (PRD §5). Flat list, no nesting.
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    # Unique per user, not globally, and case-insensitively: "Books" and
    # "books" are the same folder. An expression index rather than a collation
    # on the column, so the stored name keeps the case the user typed.
    add_index :folders, "user_id, LOWER(name)",
      unique: true, name: "index_folders_on_user_id_and_lower_name"

    # Left-rail ordering, and the plain user_id lookup index.
    add_index :folders, [ :user_id, :position ]
  end
end
