class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Always stored downcased — User normalizes on write — so a plain unique
      # index is genuinely case-insensitive without needing a collation.
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name

      # Unused until mail delivery exists (PRD §12.2). Present from milestone 1
      # so verification can be applied retroactively rather than migrated in.
      t.datetime :verified_at

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
