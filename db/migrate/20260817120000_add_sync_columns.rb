class AddSyncColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :folders, :deleted_at, :datetime
    add_index :folders, [:user_id, :updated_at]
    add_index :folders, [:user_id, :deleted_at]
    add_index :notes, [:user_id, :updated_at]
  end
end
