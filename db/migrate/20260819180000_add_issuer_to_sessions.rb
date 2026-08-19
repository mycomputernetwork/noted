class AddIssuerToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :issuer, :string
  end
end
