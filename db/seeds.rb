# Idempotent. Safe to run repeatedly against an existing development database.
#
# Creates one user, because sign-in does not exist until milestone 7 and
# current_user returns the first user unconditionally until then. A second user
# is seeded in development only, as a tripwire: if any query ever leaks across
# accounts, their content shows up where it should not.

def say(message) = puts("  #{message}")

puts "Seeding notbuk…"

owner = User.find_or_initialize_by(email: "me@notbuk.local")
owner.assign_attributes(name: "Prabhanshu", password: "notbuk-dev-password")
owner.save!
say "user #{owner.email}"

folder_names = [ "Groceries", "Packing", "Books", "Fragments" ]
folders = folder_names.index_with do |name|
  owner.folders.find_or_create_by!(name: name)
end
say "#{folders.size} folders"

# --- Notes: undated, tiled board ---------------------------------------------

NOTES = [
  { title: "Weeknight groceries", folder: "Groceries", pinned: true, body: <<~BODY },
    coffee beans
    oat milk
    tomatoes
    curd
    ginger
    green chillies
    atta
  BODY
  { title: "Kerala trip", folder: "Packing", body: <<~BODY },
    sandals not shoes
    rain shell
    universal adapter
    kindle + cable
    mosquito patches
  BODY
  { title: "To read", folder: "Books", pinned: true, body: <<~BODY },
    Stoner — John Williams
    The Peregrine — J.A. Baker
    Piranesi — Susanna Clarke
    Metamorphosis of Plants — Goethe
  BODY
  { title: nil, folder: "Fragments", body: <<~BODY },
    the way sound carries differently over water in the early morning
  BODY
  { title: "Home server ideas", folder: nil, body: <<~BODY },
    tailscale serve for TLS
    nightly sqlite .backup to the external drive
    mise instead of a system ruby
  BODY
  { title: "Guitar", folder: nil, body: <<~BODY },
    relearn the Bm barre transition
    slow down the bridge of Blackbird
  BODY
  { title: "Old grocery list", folder: "Groceries", archived: true, body: "rice\ndal\n" },
  { title: "Mistyped note", folder: nil, trashed: true, body: "asdfasdf" }
].freeze

NOTES.each do |attrs|
  note = owner.notes.find_or_initialize_by(title: attrs[:title], body: attrs[:body])
  note.folder = folders[attrs[:folder]] if attrs[:folder]
  note.pinned = attrs.fetch(:pinned, false)
  note.archived_at = attrs[:archived] ? 3.weeks.ago : nil
  note.deleted_at = attrs[:trashed] ? 2.days.ago : nil
  note.save!
end
say "#{owner.notes.count} notes (#{owner.notes.kept.count} live)"

# --- Day entries: events and actions -----------------------------------------

today = Date.current

DAY_ENTRIES = [
  # Past — some done, some deliberately left open so rollover has something
  # to carry onto today.
  { day: -6, kind: "event",  at: "09:30", body: "Dentist" },
  { day: -6, kind: "action", body: "Pay the electricity bill", done: true },
  { day: -4, kind: "action", body: "Return the router to the ISP" },
  { day: -4, kind: "event",  at: "19:00", body: "Dinner at Ranjit's" },
  { day: -3, kind: "action", body: "Book the Kochi tickets" },
  { day: -1, kind: "action", body: "Reply to Meera about the weekend", done: true },
  { day: -1, kind: "event",  body: "Server arrived" },

  # Today.
  { day: 0, kind: "event",  at: "11:00", body: "Standup" },
  { day: 0, kind: "event",  at: "16:30", body: "Physio" },
  { day: 0, kind: "event",  body: "Bin day" },
  { day: 0, kind: "action", body: "Set up mise on the MacBook Air" },
  { day: 0, kind: "action", body: "First pass at the notbuk schema", done: true },

  # Future — this is what the calendar is for.
  { day: 2,  kind: "event",  at: "20:15", body: "Flight IX 384 to Kochi" },
  { day: 2,  kind: "action", body: "Print the boarding passes" },
  { day: 5,  kind: "event",  body: "Akshatha's birthday" },
  { day: 12, kind: "event",  at: "08:00", body: "Car service" },
  { day: 30, kind: "action", body: "Renew the domain" }
].freeze

DAY_ENTRIES.each do |attrs|
  date = today + attrs[:day]
  entry = owner.day_entries.find_or_initialize_by(date: date, body: attrs[:body])
  entry.kind = attrs[:kind]
  entry.start_time = attrs[:at]
  entry.completed_at = attrs[:done] ? date.to_time + 18.hours : nil
  entry.save!
end
say "#{owner.day_entries.count} day entries " \
    "(#{owner.day_entries.open_actions.count} open, #{owner.day_entries.carried_into(today).count} carried onto today)"

# --- Day logs: things I did that day ------------------------------------------

DAY_LOGS = {
  -6 => "Dentist was quick. Spent the afternoon reading about SQLite WAL mode\nand whether it matters at this scale. It does not.",
  -4 => "Cooked properly for the first time in a week.",
  -3 => "Long walk. Sketched out how the calendar and the notes should be\nseparate things rather than one table with a date on it.",
  -1 => "Unboxed the Air. Wiped it, installed mise, nothing else. Keeping it\nclean this time.",
   0 => "Started notbuk for real. Schema first."
}.freeze

DAY_LOGS.each do |offset, body|
  log = owner.day_logs.find_or_initialize_by(date: today + offset)
  log.body = body
  log.save!
end
say "#{owner.day_logs.written.count} day logs"

# --- Isolation tripwire (development only) ------------------------------------

if Rails.env.development?
  other = User.find_or_initialize_by(email: "someone-else@notbuk.local")
  other.assign_attributes(name: "Not you", password: "notbuk-dev-password")
  other.save!

  other_folder = other.folders.find_or_create_by!(name: "Groceries")
  other.notes.find_or_create_by!(title: "LEAK CANARY") do |note|
    note.body = "If you can see this note anywhere in the UI, a query escaped current_user."
    note.folder = other_folder
    note.pinned = true
  end
  other.day_entries.find_or_create_by!(date: today, body: "LEAK CANARY EVENT") do |entry|
    entry.kind = "event"
  end
  other.day_logs.find_or_create_by!(date: today) { |log| log.body = "LEAK CANARY LOG" }

  say "second user seeded as a leak canary — its folder is also called 'Groceries'"
end

puts "Done."
