class AddFolderBoardPositionToNotes < ActiveRecord::Migration[8.0]
  def change
    add_column :notes, :folder_board_position, :integer
    add_index :notes, [ :user_id, :folder_id, :folder_board_position ], name: "index_notes_on_folder_board_order"
  end
end
