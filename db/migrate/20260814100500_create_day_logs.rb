class CreateDayLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :day_logs, id: :string do |t|
      t.references :user, null: false, foreign_key: true, index: false, type: :string
      t.date :date, null: false
      t.text :body, null: false, default: ""

      t.timestamps
    end

    add_index :day_logs, [ :user_id, :date ], unique: true
  end
end
