# notbuk

A self-hosted personal notes and calendar application. Rails 8, SQLite, Hotwire,
no Node toolchain, no third-party services.

**Milestone 2 of 12.** The data layer plus the tiled board: design tokens,
note cards and masonry. Notes are read-only for now — the editor arrives at
milestone 3, so nothing on the board can be changed yet.

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

## Documentation

`docs/PRD.md` is the product requirements document — the source of truth for
what this is and what order it gets built in. Code comments cite it by
section. `docs/previews/` holds static HTML mockups of built and upcoming
views; see the README there.

## The board

`root` is the tiled board: every kept note, pinned ones in their own section
above the rest, sorted by last edited or created in either direction. Sort is
URL state (`/?sort=created&direction=asc`) rather than session state, so a
board is linkable and the back button behaves.

Masonry is a CSS grid of 1px rows; `masonry_controller.js` measures each card
and gives it a row span equal to its own height. CSS `columns` would pack for
free and is deliberately not used — it fills column one top to bottom before
starting column two, so with "last edited" sorting the newest note lands
halfway down the screen and reading order stops matching sort order. Without
JavaScript the same markup is a plain equal-height grid: less tightly packed,
fully readable.

## Design tokens

`app/assets/stylesheets/application.css` opens with the entire token set —
surface, text, border, accent, spacing, radius, type, elevation, motion. Every
component below it refers to tokens only, never to a raw colour or pixel
value. That constraint is what makes the Android theme a translation of one
block rather than a reinterpretation of the whole stylesheet. Dark only, on
purpose; there is no light theme to keep in sync until one is wanted.

Type is sized by role rather than by one multiplier: an 18px card body is the
base, because the board is scanned at desk distance rather than read at
document distance. Titles are 22, chrome 15, metadata 13, section labels 12.
Scaling all five together — which is what overriding the root size does — makes
timestamps and folder chips compete with the note text, and makes an uppercase
tracked label shout. Card width follows the body size: 280px is roughly a
45-character measure at 18px.

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
| 2 | Tiled board, card design, masonry, CSS tokens | ✅ |
| 3 | Editor modal, autosave, create-on-keystroke | |
| 4 | Sidebar tree — folders, note rows, full-pane note, drag-to-file | |
| 5 | Images — upload, gallery, thumbnails | |
| 6 | Calendar day stream, inline editing, day log | |
| 7 | Auth — email + password, sessions, rate limiting | |
| 8 | Search, archive, trash | |
| 9 | Tailscale, mise on the server, Capistrano deploy | |
| 10 | Android | |
| 11 | Reminders | |
| 12 | Keep import | |
| 13 | Manual ordering — drag to reorder folders and notes | |
