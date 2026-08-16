class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions, id: :string do |t|
      t.references :user, null: false, foreign_key: true, type: :string

      t.string :ip_address
      t.string :user_agent
      t.datetime :last_active_at, null: false

      t.timestamps
    end

    add_index :sessions, :last_active_at
  end
end
