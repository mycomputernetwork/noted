# Idempotent. Safe to run repeatedly against an existing development database.
#
# The two users match the first two identities in config/dev_users.yml, so the
# development sign-in picker lands on seeded content rather than an empty board.
# The second is also a tripwire: if any query ever leaks across accounts, its
# content shows up where it should not.

def say(message) = puts("  #{message}")

puts "Seeding noted…"

owner = User.find_or_initialize_by(email: "dev1@example.com")
owner.assign_attributes(name: "Dev user 1", auth_sub: "stub-1")
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

# --- Calendar ---------------------------------------------------------------

today = Date.current
month = today.strftime("%b").downcase
calendar = owner.year_docs.find_or_initialize_by(year: today.year)
calendar.body = <<~BODY
  #{(today + 5).day} #{(today + 5).strftime("%b").downcase}
  Akshatha's birthday

  #{(today + 2).day} #{(today + 2).strftime("%b").downcase}
  20:15 Flight IX 384 to Kochi
  Print the boarding passes

  #{today.day} #{month}
  11:00 Standup
  16:30 Physio
  Set up mise on the MacBook Air
  First pass at the noted schema done

  #{(today - 1).day} #{(today - 1).strftime("%b").downcase}
  Reply to Meera about the weekend done
  Unboxed the Air. Wiped it, installed mise, nothing else.

  #{(today - 4).day} #{(today - 4).strftime("%b").downcase}
  Return the router to the ISP
  Dinner at Ranjit's 19:00

  #{(today - 6).day} #{(today - 6).strftime("%b").downcase}
  Dentist 09:30
  Pay the electricity bill done
BODY
calendar.save!
say "calendar #{calendar.year} seeded"

# --- Isolation tripwire (development only) ------------------------------------

if Rails.env.development?
  other = User.find_or_initialize_by(email: "dev2@example.com")
  other.assign_attributes(name: "Dev user 2", auth_sub: "stub-2")
  other.save!

  other_folder = other.folders.find_or_create_by!(name: "Groceries")
  other.notes.find_or_create_by!(title: "LEAK CANARY") do |note|
    note.body = "If you can see this note anywhere in the UI, a query escaped current_user."
    note.folder = other_folder
    note.pinned = true
  end
  other.year_docs.find_or_create_by!(year: today.year) do |doc|
    doc.body = "#{today.day} #{month}\nLEAK CANARY CALENDAR\n"
  end

  say "second user seeded as a leak canary — its folder is also called 'Groceries'"
end

puts "Done."
