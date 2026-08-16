class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :string do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name
      t.datetime :verified_at

      t.timestamps
    end

    # Emails are stored downcased, so a plain unique index is case-insensitive
    # without a collation.
    add_index :users, :email, unique: true
  end
end
