class CreateFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :folders, id: :string do |t|
      t.references :user, null: false, foreign_key: true, index: false, type: :string
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :folders, [ :user_id, :position ]
  end
end
