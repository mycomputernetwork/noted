class AddBoardPositionToNotes < ActiveRecord::Migration[8.0]
  def change
    add_column :notes, :board_position, :integer
    add_index :notes, [ :user_id, :board_position ]
  end
end
