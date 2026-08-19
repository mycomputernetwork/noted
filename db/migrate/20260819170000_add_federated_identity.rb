class AddFederatedIdentity < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :auth_sub, :string
    add_index :users, :auth_sub, unique: true
    change_column_null :users, :password_digest, true

    add_column :sessions, :sid, :string
    add_index :sessions, :sid, unique: true
  end
end
