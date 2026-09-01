class AddFolderBoardPositionToNotes < ActiveRecord::Migration[8.0]
  def change
    add_column :notes, :folder_board_position, :integer
    add_index :notes, [ :user_id, :folder_id, :folder_board_position ], name: "index_notes_on_folder_board_order"

    reversible do |direction|
      direction.up do
        execute <<~SQL
          CREATE TRIGGER clear_folder_board_position_after_unfile
          AFTER UPDATE OF folder_id ON notes
          WHEN OLD.folder_id IS NOT NULL AND NEW.folder_id IS NULL
          BEGIN
            UPDATE notes SET folder_board_position = NULL WHERE id = NEW.id;
          END;
        SQL
      end

      direction.down do
        execute "DROP TRIGGER IF EXISTS clear_folder_board_position_after_unfile"
      end
    end
  end
end
