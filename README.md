# notbuk

A self-hosted personal notes and calendar application. Rails 8, SQLite, Hotwire,
no Node toolchain, no third-party services.

**Milestone 4 of 14.** The data layer, the tiled board, the editor, and the
sidebar: notes can be written, filed and pinned, found again in a folder tree,
and opened full-pane. There is no save button — there is not going to be one.

## Documentation

| | |
|---|---|
| `docs/PRD.md` | What is being built and why. Written as argument, not specification — most decisions live here rather than in a record of their own. |
| `docs/ADR/` | Decision records. Currently: the JSON API that serves the native clients, and how it divides work with the HTML surface. |
| `docs/api-plan.md` | How the API gets built, endpoint by endpoint and milestone by milestone. |
| `docs/handoff.md` | Where the work actually stands today, what to click first, and what is known to be unexercised. |
| `docs/previews/` | Dated static design artefacts. Deliberately not kept in step with the app. |

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

## The editor

Click a card and it opens in a native `<dialog>` over the board; Escape, the
backdrop and Close are the same action and all of them save.

The "take a note" field at the top of the board is the other way in, and it
does **not** open a dialog — it expands into the editor where it stands. A
modal exists to keep something visible behind it, and a new note has nothing
behind it worth a scrim; expanding in place also means the note is written
where it is about to live. A click outside, Escape or Done all finish it. On
close the board re-sorts around the new note and the card it landed in is
highlighted and focused, because a note that drops unannounced into a few
hundred cards has to be found again.

A note opened from the sidebar instead fills the pane, with the tree still
beside it. Same URL as the modal: a card asks for the note into the board's
editor frame and gets the dialog, the sidebar links to it plainly and gets the
pane. The rule is where you clicked, never how long the note is.

All three surfaces render one field partial that knows nothing about the frame
around it, and mount one autosave controller.

Saving is implicit and there is no save button anywhere. `autosave_controller.js`
debounces 800ms after typing stops, saves at once on blur and on a deliberate
change (folder, pin), and flushes on unload and on Turbo navigation with
`keepalive` so a navigation cannot swallow the last keystroke. Requests are
chained rather than parallel, so a slow response can never land after a newer
one and resurrect stale text.

The record is created on the **first keystroke**, not when the editor opens:
opening it and walking away writes nothing. The mirror of that rule is
`DELETE /notes/:id`, which discards a note that was typed into and emptied out
again — and refuses anything that still has content in it, so a bug in the
autosave path can cost a keystroke but never a note. Trashing a note you still
want gone is milestone 8.

A failed save backs off and retries on its own — a second, then two, up to
thirty — rather than waiting for the next keystroke to carry it, and retries at
once if the machine comes back online. The status line says what is actually
happening.

The controller is deliberately surface-agnostic: it takes a form, a create URL
and an update URL and knows nothing about dialogs. The full-pane note mounts it
unchanged, which was the test of whether it was built right.

Closing refreshes the board rather than patching the card in place, because
editing a note is exactly what moves it to the front under "last edited"
sorting. The layout asks Turbo for morphing, so that refresh is a patch: scroll
holds and only the cards that actually moved move.


## The sidebar

Present on every view and the primary navigation: views, then a folder tree,
then archive and trash. Folders expand to the notes inside them and unfiled
notes sit at the root, so nothing in the account is unreachable from it. The
board answers *what have I touched lately*; the tree answers *where did I put
that*, and neither subsumes the other.

`Tree` is a plain object beside `Day` and `Year` — two queries, grouped in
Ruby, no round trip per disclosure triangle. Which folders are open is
interface state rather than user data, so it lives in `localStorage`; what is
stored is the *collapsed* set, so a folder made later opens by default.

Drag a card onto a folder to file it, or onto Notes to unfile it. That is a
`PATCH` to the note, not a folder operation, so it needs no route of its own.
Folders are created, renamed and deleted here and nowhere else; deleting one
unfiles its notes rather than destroying them.

## Design tokens

`app/assets/stylesheets/application.css` opens with the entire token set —
surface, text, border, accent, spacing, radius, type, elevation, motion. Every
component below it refers to tokens only, never to a raw colour or pixel
value. That constraint is what makes the Android theme a translation of one
block rather than a reinterpretation of the whole stylesheet. Dark only, on
purpose; there is no light theme to keep in sync until one is wanted.

Type is sized by role rather than by one multiplier: a 17px card body is the
base, because the board is scanned at desk distance rather than read at
document distance. Titles are 21, chrome 14, metadata 12.5, section labels 11.
Scaling all five together — which is what overriding the root size does — makes
timestamps and folder chips compete with the note text, and makes an uppercase
tracked label shout. Card width follows the body size: 17rem is roughly a
45-character measure at 17px.

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
| 3 | Editor modal, autosave, create-on-keystroke | ✅ |
| 4 | Sidebar tree — folders, note rows, full-pane note, drag-to-file | ✅ |
| 5 | Images — upload, gallery, thumbnails | |
| 6 | Calendar day stream, inline editing, day log | |
| 7 | Auth — email + password, sessions, rate limiting | |
| 8 | Search, archive, trash | |
| 9 | Tailscale, mise on the server, Capistrano deploy | |
| 10 | Android | |
| 11 | Reminders | |
| 12 | Keep import | |
| 13 | Manual ordering — drag to reorder folders and notes | |
| 14 | Version history — read-only slider over past bodies | |
