class ReplaceCalendarRecordsWithYearDocs < ActiveRecord::Migration[8.0]
  def change
    create_table :year_docs, id: :string do |t|
      t.references :user, null: false, foreign_key: true, index: false, type: :string
      t.integer :year, null: false
      t.text :body, null: false, default: ""
      t.timestamps
    end

    add_index :year_docs, [ :user_id, :year ], unique: true

    drop_table :day_entries do |t|
      t.references :user, null: false, foreign_key: true, index: false, type: :string
      t.string :kind, null: false
      t.date :date, null: false
      t.text :body, null: false, default: ""
      t.integer :start_minute
      t.datetime :completed_at
      t.integer :position, null: false, default: 0
      t.datetime :deleted_at
      t.timestamps
    end

    drop_table :day_logs do |t|
      t.references :user, null: false, foreign_key: true, index: false, type: :string
      t.date :date, null: false
      t.text :body, null: false, default: ""
      t.timestamps
    end
  end
end
