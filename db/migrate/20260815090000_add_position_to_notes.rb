class AddPositionToNotes < ActiveRecord::Migration[8.1]
  def change
    # Null means not yet hand-placed; shipped now to avoid a later migration
    # against a populated table.
    add_column :notes, :position, :integer

    add_index :notes, [ :user_id, :folder_id, :position ],
      name: "index_notes_on_tree_order"
  end
end
