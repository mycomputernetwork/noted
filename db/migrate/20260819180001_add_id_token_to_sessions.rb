class AddIdTokenToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :id_token, :text
  end
end
