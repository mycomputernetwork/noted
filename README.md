# notbuk

A self-hosted personal notes and calendar application. Rails 8, SQLite, Hotwire,
no Node toolchain, no third-party services.

**Milestone 1 of 12.** This is the data layer: schema, models, ownership
scoping, seeds and tests. There is no interface yet beyond a plain smoke-test
page — the tiled board starts at milestone 2.

## The three objects

Notes and the calendar are deliberately separate. A note cannot be put on a day,
and nothing on a day is a note.

| | What it is | Where it lives |
|---|---|---|
| `Note` | An undated thought, list or fragment. Title, plain-text body, optional folder, pinnable, images. | Tiled board |
| `DayEntry` | Something on a day. `kind: "event"` (may carry a time) or `kind: "action"` (may be completed). | Calendar day stream |
| `DayLog` | "Things I did today." One free-text block per day, at most one per day. | Bottom of each day |

`Day` and `Year` are plain objects, not tables — days are not materialised,
because a year is mostly empty and 365 rows per user per year holding nothing
would be pure overhead. `Year.for(user:, number:)` assembles a whole calendar
year in three queries.

### Action rollover

An unfinished action from a past day surfaces on **today**, so nothing is
silently stranded in the past. This is a read, not a write: `date` keeps
recording when the thing was originally planned for, and no nightly job
re-dates anything. Carried items appear on today only — ghosting them onto
every future day would make the whole calendar look overdue.

## Getting started

Ruby is pinned to **3.4.10** and Rails to **8.1** (currently 8.1.3.1). Ruby 4.0
exists but Rails 8.1 does not officially support it — it requires `>= 3.2` and
recommends 3.4.x, and there are open reports of bundled-gem `LoadError`s on
Ruby 4.

```sh
mise install                  # installs the Ruby pinned in .mise.toml
mise exec -- bundle install   # gems land in vendor/bundle, not user-wide
mise exec -- bin/rails db:prepare
mise exec -- bin/rails test
mise exec -- bin/rails server
```

Then open http://localhost:3000.

`mise exec --` is only needed if mise isn't activated in your shell. To drop it,
add the activation line to `~/.zshrc` once:

```sh
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc && exec zsh
```

Check it took with `ruby -v` (expect 3.4.10) and `bundle -v` (expect 2.6+). If
`bundle -v` reports 2.0 or lower you are still on the system Ruby, and the
Gemfile's `ruby file:` directive will fail before anything else does.

Seeds create `me@notbuk.local` (password `notbuk-dev-password`) plus a second
account whose content is labelled `LEAK CANARY`. If a canary ever shows up in
the interface, a query has escaped `current_user`.

## Ownership

Every query originates from `current_user` — `current_user.notes`,
`current_user.folders`, `current_user.day_entries`. Nothing is ever loaded by
bare id from a global scope, in any controller, at any point. That rule is the
entire isolation model between accounts, so it is habit from the first
controller rather than a later audit.

`ApplicationController` exposes `notes`, `folders`, `entries` and `logs` as the
only entry points, and `test/models/isolation_test.rb` asserts the property
directly.

Sign-in does not exist until milestone 7. Until then `current_user` returns the
first user unconditionally — a stub in `app/controllers/concerns/authentication.rb`
that milestone 7 deletes without touching anything else.

## Runtime

`mise` rather than a system Ruby or Nix: it shims Ruby on PATH inside this
directory and touches nothing else on the machine. No system Ruby is replaced,
nothing is written to `/usr/local`, and deleting the project deletes the
footprint. `BUNDLE_PATH` is set to `vendor/bundle` so two apps on the same
server can never fight over a gem version.

## What is deliberately absent

No Markdown or rich text — bodies are plain text everywhere. No per-note
colours; folders are the only organising axis. No tags as a separate axis. No
sharing or collaboration between accounts. Note contents are stored
unencrypted; passwords are bcrypt-hashed and never recoverable.

## Milestones

| # | Deliverable | |
|---|---|---|
| 1 | Schema, models, scoping, seeds | ✅ |
| 2 | Tiled board, card design, masonry, CSS tokens | |
| 3 | Editor modal, autosave, create-on-keystroke | |
| 4 | Folders, left rail, drag-to-file | |
| 5 | Images — upload, gallery, thumbnails | |
| 6 | Calendar day stream, inline editing, day log | |
| 7 | Auth — email + password, sessions, rate limiting | |
| 8 | Search, archive, trash | |
| 9 | Tailscale, mise on the server, Capistrano deploy | |
| 10 | Android | |
| 11 | Reminders | |
| 12 | Keep import | |
