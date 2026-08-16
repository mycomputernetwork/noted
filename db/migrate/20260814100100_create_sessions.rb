class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions, id: :string do |t|
      t.references :user, null: false, foreign_key: true, type: :string

      # Enough to tell one device from another on a "signed-in devices" screen
      # so an individual session can be revoked (PRD §12.4).
      t.string :ip_address
      t.string :user_agent

      # Sessions are 30 days *sliding*, so the expiry clock is this column
      # rather than created_at.
      t.datetime :last_active_at, null: false

      t.timestamps
    end

    add_index :sessions, :last_active_at
  end
end
