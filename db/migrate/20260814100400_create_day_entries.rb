class CreateDayEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :day_entries, id: :string do |t|
      t.references :user, null: false, foreign_key: true, index: false, type: :string

      # "event"  — something happening on the day. May carry a time.
      # "action" — something to do on the day. Carries completion state.
      #
      # String rather than integer so the column reads plainly in a SQLite
      # browser and in any future JSON payload to the Android client.
      t.string :kind, null: false

      t.date :date, null: false
      t.text :body, null: false, default: ""

      # Minutes from midnight, 0..1439. Events only.
      #
      # Deliberately not a `time` column: SQLite stores those against a dummy
      # 2000-01-01 date, which leaks into serialization and invites timezone
      # bugs for a value that has no timezone. An integer sorts correctly,
      # renders trivially on any client, and cannot be misread.
      t.integer :start_minute

      # Actions only. Null means open.
      t.datetime :completed_at

      # Manual ordering within a day, for entries with no time.
      t.integer :position, null: false, default: 0

      t.datetime :deleted_at

      t.timestamps

      t.check_constraint "kind IN ('event', 'action')",
        name: "day_entries_kind_valid"
      t.check_constraint "start_minute IS NULL OR (start_minute >= 0 AND start_minute <= 1439)",
        name: "day_entries_start_minute_range"
      # An action has no clock time and an event has no completion state.
      t.check_constraint "kind = 'event' OR start_minute IS NULL",
        name: "day_entries_time_events_only"
      t.check_constraint "kind = 'action' OR completed_at IS NULL",
        name: "day_entries_completion_actions_only"
    end

    # Rendering one day, and one calendar year of days.
    add_index :day_entries, [ :user_id, :date, :kind, :start_minute, :position ],
      name: "index_day_entries_on_day_ordering"

    # Open actions carried forward from past days onto today. Partial index so
    # it only covers the rows the rollover query actually scans.
    add_index :day_entries, [ :user_id, :date ],
      where: "kind = 'action' AND completed_at IS NULL AND deleted_at IS NULL",
      name: "index_day_entries_open_actions"

    add_index :day_entries, [ :user_id, :deleted_at ]
  end
end
