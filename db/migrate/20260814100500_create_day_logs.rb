class CreateDayLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :day_logs, id: :string do |t|
      t.references :user, null: false, foreign_key: true, index: false, type: :string

      t.date :date, null: false

      # "Things I did today." One free-text block per day, plain text.
      t.text :body, null: false, default: ""

      t.timestamps
    end

    # At most one log per day per user. Also the lookup index for rendering a
    # year of days, since user_id leads and date is the range column.
    add_index :day_logs, [ :user_id, :date ], unique: true
  end
end
