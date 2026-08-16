class CreateDayEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :day_entries, id: :string do |t|
      t.references :user, null: false, foreign_key: true, index: false, type: :string

      t.string :kind, null: false
      t.date :date, null: false
      t.text :body, null: false, default: ""

      # Minutes from midnight, not a `time` column: SQLite stores time against a
      # dummy date, which invites timezone bugs for a value that has none.
      t.integer :start_minute

      t.datetime :completed_at
      t.integer :position, null: false, default: 0
      t.datetime :deleted_at

      t.timestamps

      t.check_constraint "kind IN ('event', 'action')",
        name: "day_entries_kind_valid"
      t.check_constraint "start_minute IS NULL OR (start_minute >= 0 AND start_minute <= 1439)",
        name: "day_entries_start_minute_range"
      t.check_constraint "kind = 'event' OR start_minute IS NULL",
        name: "day_entries_time_events_only"
      t.check_constraint "kind = 'action' OR completed_at IS NULL",
        name: "day_entries_completion_actions_only"
    end

    add_index :day_entries, [ :user_id, :date, :kind, :start_minute, :position ],
      name: "index_day_entries_on_day_ordering"

    # Partial index for the open-actions-carried-forward query.
    add_index :day_entries, [ :user_id, :date ],
      where: "kind = 'action' AND completed_at IS NULL AND deleted_at IS NULL",
      name: "index_day_entries_open_actions"

    add_index :day_entries, [ :user_id, :deleted_at ]
  end
end
