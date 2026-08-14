# notbuk — product requirements

**Status:** v7 — version history specified (milestone 14)
**Owner:** single user (self-hosted)
**Last updated:** 14 Aug 2026

---

## 1. Summary

A self-hosted personal application replacing Google Keep, with a calendar and a
daily log alongside it. Rails web app deployed to a home server, followed by an
Android client sharing the same visual language.

**Notes and the calendar are separate things.** This is the central change from
v2, which modelled them as one table switched by the presence of a date.

- **Notes** — undated, browsed as a tiled board. Groceries, packing lists, book
  lists, fragments. A note *cannot* be scheduled to a day.
- **Calendar** — a vertical stream of days. Each day holds events and action
  items, and ends with a free-text record of what actually happened.

Collapsing the two into one object made "a note with a date" ambiguous — it was
neither a good calendar entry (no time, no completion) nor a good note. They are
now distinct objects with distinct affordances, and there is deliberately no
migration path between them.

## 2. Goals

- Own the data. No third-party service, no export anxiety.
- Match Keep's speed of capture — open, type, close, saved.
- Make a year of days scannable and navigable in a way a calendar app isn't.
- Keep a record of what was actually done, not only what was planned.
- Single codebase of visual tokens shared between web and Android.
- Deployment that doesn't pollute the host machine and is reproducible months
  later.

## 3. Non-goals

- Sharing, collaboration, or permissions *between* users. Multi-account, not
  multi-player.
- Encryption of note contents at rest. Bodies and titles are plaintext in SQLite.
- Markdown or rich text. All bodies are plain text, always.
- Per-note colours. Folders are the only organising axis.
- Real-time sync between concurrent clients (last write wins is acceptable).
- Tags/labels as a separate axis from folders.
- Offline-first web app.
- **Dating a note.** There is no `entry_date` on `Note` and no control that
  would add one.

Reminders are **deferred, not excluded** — see §10.

## 4. Users and context

A small number of accounts — the owner plus family members — reachable over
Tailscale. Each account is a **fully independent, private workspace**. No user
can see another's content, and there is no mechanism to share anything.

Expected scale: low thousands of notes per user, low hundreds of images, growing
slowly over years. Performance work should be justified against that.

## 5. Data model

### User

| Field | Type | Notes |
|---|---|---|
| `email` | string, unique | Downcased on write. The identity key. |
| `password_digest` | string | bcrypt via `has_secure_password` |
| `name` | string, nullable | |
| `verified_at` | datetime, nullable | Unused for now; present so verification can be added retroactively |

Related table: `Session` (per-device, revocable). See §12.

### Note — undated only

| Field | Type | Notes |
|---|---|---|
| `user_id` | fk, not null | Owner |
| `title` | string, nullable | Optional, as in Keep |
| `body` | text | Plain text. No markup. |
| `folder_id` | fk, nullable | Zero or one folder |
| `pinned` | boolean, default false | Pinned notes sort first |
| `archived_at` | datetime, nullable | Soft hide from all views |
| `deleted_at` | datetime, nullable | Trash; purged after 30 days |
| `position` | integer, nullable | Manual order **in the sidebar tree only** |
| images | Active Storage `has_many_attached` | Ordered |

No date column of any kind.

**`position` orders the sidebar, not the board.** The board sorts by edited or
created (§7.1) and must keep doing so — a board that is manually ordered stops
answering "what did I touch recently", which is the question it exists to
answer. The sidebar tree is the opposite: a stable, hand-arranged shelf where a
note stays where it was put. One column, two orderings, no conflict, because
each view names the ordering it uses rather than sharing one.

Null means unordered, and unordered notes sort after positioned ones by title.
Dragging a note in the tree for the first time assigns positions to that
folder's notes in their current displayed order, so the first drag does not
scramble everything around it.

### DayEntry — one row per thing on a day

| Field | Type | Notes |
|---|---|---|
| `user_id` | fk, not null | Owner |
| `kind` | string, not null | `"event"` or `"action"`. CHECK-constrained. |
| `date` | date, not null | The day it belongs to |
| `body` | text | Plain text, usually one line |
| `start_minute` | integer, nullable | **Events only.** Minutes from midnight, 0–1439 |
| `completed_at` | datetime, nullable | **Actions only.** Null means open |
| `position` | integer | Manual ordering within the day, for untimed entries |
| `deleted_at` | datetime, nullable | Soft delete, purged after 30 days |

One table with a `kind` column rather than two tables: events and actions are
the same shape, render in the same day, and are captured through the same
control. A third kind later is a value, not a migration.

**`start_minute` rather than a `time` column.** SQLite stores `time` values
against a dummy 2000-01-01 date, which leaks into serialisation and invites
timezone bugs for a value that has no timezone. An integer sorts correctly,
renders trivially on any client, and cannot be misread. Cross-field rules
(`only events carry a time`, `only actions carry completion`) are enforced by
both database CHECK constraints and model validations.

### DayLog — "things I did today"

| Field | Type | Notes |
|---|---|---|
| `user_id` | fk, not null | Owner |
| `date` | date, not null | Unique per user |
| `body` | text | Plain text, free-form |

One free-text block per day, not a list of items. Entries are things planned
*for* the day; the log is the record of what actually happened. They are
separate objects because they're written at different times of day and edited
with different rhythms — the log is one growing paragraph, entries are discrete
lines that get checked off.

### Version — read-only history of a text body

| Field | Type | Notes |
|---|---|---|
| `record_type` | string, not null | `"Note"` today, `"DayLog"` at milestone 6 |
| `record_id` | fk, not null | The thing this is a version of |
| `title` | string, nullable | Null for records that have no title |
| `body` | text | The body **as it was before** the save that displaced it |
| `created_at` | datetime | When that content stopped being current |

**Polymorphic from the start.** A `note_versions` table would be simpler and
would be wrong within one milestone: the "did today" log (§7.2) is free text
edited with exactly the same implicit-save rhythm and wants exactly the same
history. One extra column now costs nothing; adding it to a populated table
later is a migration nobody wants to write.

Versions inherit scoping through their parent record, the way image blobs do
(§5, scoping rule). There is no `user_id` here, and nothing loads a version
except through `current_user`'s note.

A version stores **text only** — never images. History answers "what did this
say", not "what was attached to it", and versioning Active Storage
attachments is a different and much larger feature.

### Folder

| Field | Type | Notes |
|---|---|---|
| `user_id` | fk, not null | Owner |
| `name` | string | Unique **per user**, case-insensitively |
| `position` | integer | Manual ordering in the left rail |

Flat — no nesting. Folders apply to notes only; day entries are not foldered.
Revisit only if the flat list exceeds ~15 entries in practice.

### Days are not a table

`Day` and `Year` are plain Ruby objects that compose entries and logs for
rendering. A year is mostly empty, so materialising 365 rows per user per year
to hold nothing would be pure overhead. `Year.for(user:, number:)` assembles a
full calendar year in three queries.

### Action rollover

An unfinished action from a past day surfaces on **today**, so nothing is
silently stranded in the past.

The rollover is a **read, not a write**: `date` keeps recording when the thing
was originally planned for, and no nightly job re-dates anything. Carried items
appear on today only — ghosting them onto every subsequent day would make the
whole future look overdue. A partial index covers the query.

### Scoping rule

Every query originates from `current_user` — `current_user.notes`,
`current_user.day_entries`, `current_user.folders`. Nothing is ever loaded by
bare id from a global scope, in any controller, at any point. This is the entire
isolation model, so it needs to be habit from the first controller rather than a
later audit.

Image blobs inherit scoping through their parent note. Direct-upload endpoints
must verify the note's owner before attaching.

## 6. Information architecture

A persistent left sidebar, present on every view, is the primary navigation.

```
┌────────────────────┬──────────────────────────────┐
│ Notes              │                              │
│ Calendar           │                              │
│ ────────────       │      board / day stream      │
│ ▾ Groceries        │                              │
│     Weeknight…     │                              │
│     Party list     │                              │
│ ▸ Packing          │                              │
│ ▾ Books            │                              │
│     To read        │                              │
│   Home server…     │  ← unfiled notes at the root │
│   Guitar           │                              │
│ ────────────       │                              │
│ Archive            │                              │
│ Trash              │                              │
└────────────────────┴──────────────────────────────┘
```

Two axes, deliberately. The board answers *what have I touched lately* — every
note, newest first, nothing hidden behind a disclosure triangle. The tree
answers *where did I put that* — a stable shelf where a note stays where it was
filed. Neither subsumes the other, which is why the sidebar lists notes
individually rather than only folders: a folder row alone makes finding one
known note a two-step guess.

Notes and Calendar are genuinely different views over different tables, not two
filters on one. Nothing moves between them, and the calendar has no presence in
the tree — day entries are not filed and never appear as rows.

## 7. Views

### 7.1 Tiled board (P0)

Masonry grid of note cards, Keep-style.

- Cards show title, body clamped to ~12 lines, and a thumbnail strip if the note
  has images.
- Pinned section above the rest.
- Sort: last edited (default), date created. Ascending/descending.
- Card ordering must read left-to-right, top-to-bottom, so column-flow masonry
  (CSS `columns`) is unacceptable. Use a grid with computed row spans.
- Cards are drag sources for folder filing.

### 7.2 Calendar — vertical day stream (P0)

One continuous scroll of consecutive days for a calendar year. Each non-empty
day renders three sections in order:

1. **Events** — timed ones first in clock order, then untimed in manual order.
2. **Actions** — open items, including anything carried in from earlier days
   (labelled with the day it came from). Completed items shown struck through.
3. **Did today** — the free-text log.

- Empty days collapse to a thin (~28px) row showing just the date.
- Today is anchored on load, near the top of the viewport.
- Today's row is visually distinguished (accent border and tint).
- Month headers stick to the top of the viewport.
- Weekend rows carry a subtle background tint, giving the year a 5-2 rhythm.
- The full calendar year renders in one page load. Year navigation at head and
  foot (`← 2025`, `2027 →`).

### 7.3 Folder view (P0)

Identical to the tiled board, filtered to one folder.

### 7.4 Search (P1)

Header search box. Full-text over note titles/bodies, day entry bodies, and day
logs via SQLite FTS5. Results grouped by type.

### 7.5 Archive and trash (P1)

Archive applies to notes only. Trash is a soft delete with a 30-day purge and
covers both notes and day entries.

### 7.6 Sidebar tree (P0)

Persistent on every view, collapsible to a rail on narrow viewports.

- Views first (Notes, Calendar), then the folder tree, then Archive and Trash.
- Each folder row expands to its notes; **unfiled notes sit at the root of the
  tree**, below the folders, so nothing is unreachable from the sidebar.
- Note rows show the title, or the first line of the body when there is no
  title, truncated to one line. Never two lines — a tree whose row heights vary
  cannot be scanned vertically.
- Expansion state persists per folder across page loads. It is interface state,
  not user data: `localStorage`, not a column.
- Clicking a note row opens that note **full-pane** (§7.7). Clicking the same
  note's card on the board opens the **modal** (§8.2). Same note, same edits,
  different surface depending on where it was clicked — see §8.4 for why both
  exist.
- Clicking a folder row's name filters the board to that folder (§7.3);
  clicking its triangle expands it. Two targets, one row.
- The current note or folder is marked in the tree, so the sidebar always shows
  where you are.
- Empty folders still render, with a dimmed "empty" affordance — a folder that
  vanishes when its last note is filed elsewhere is a folder you cannot drop
  onto.
- Archived and trashed notes never appear in the tree.

The tree is rendered from the same three-query load as the board and is not
lazily fetched per folder. At the expected scale (§4) the whole tree is a few
hundred rows of text, which is cheaper to send once than to round-trip on every
disclosure triangle.

### 7.7 Full-pane note (P0)

A note opened from the sidebar fills the main pane, with the sidebar still in
place beside it.

- Editable in place, not a reading view: the title and body are the real
  fields, saved by the same autosave controller as everywhere else (§8.1).
- One measure of about 46rem, centred. A note that fills a 27-inch display
  edge to edge is unreadable, and the pane is the surface for the notes long
  enough to be worth opening this way.
- Its own URL, so a note is linkable and the back button works.
- A back affordance returns to whatever board was underneath — the folder's
  board if the note came from a folder, otherwise all notes.
- The note's row stays marked in the tree while it is open.
- Images, folder and pin controls are the same components the modal uses, not
  a second implementation.

## 8. Editing

### 8.1 Shared behaviour

- **Saving is implicit.** No save button anywhere. Debounced ~800ms after typing
  stops, and again on blur or close.
- A new record is created on the first keystroke, not when the surface is
  focused. Focusing and leaving without typing creates nothing.
- Autosave is a standalone client-side controller, not a property of any one
  surface, precisely so every surface can use it.
- No interaction may lose data.

### 8.2 Modal editor (notes)

Opens on card click. Fields: title, body, folder, pin, images. Closes on
backdrop click, Escape, or Close — all equivalent, all save. There is no date
control.

Pin sits in the top-right corner of the editor rather than in the row of
controls along the bottom: it is a property of the note, not a step in writing
one. Cards carry no pin badge — a pinned note is already under the Pinned
heading, and repeating that on each card is decoration.

### 8.2a The composer — a new note is written in place

The "take a note" field at the top of a board expands into the editor **where
it stands**, not into a dialog. Same fields, same autosave, no scrim.

A modal exists to keep something visible behind it. A new note has nothing
behind it to refer to, so the scrim would cost the board for nothing — and it
would put the note being written somewhere other than where it is about to
live. Expanding in place means the composer is the card it is about to become.

Done is a click outside, Escape, or the Done button; all three are the same
act and all three save, as the modal's three ways of closing are.

**On close the note takes its place on the board and is marked there.** The
board re-sorts around it — under "last edited" a new note goes to the front —
and the card it landed in is highlighted, focused and scrolled to. A board can
be a few hundred cards; a note that drops into one unannounced has to be found
again, which undoes the capture speed the composer exists for (§17). The mark
lasts until the next render, which is as long as the question does.

If nothing was typed, nothing was created (§8.1), so the composer collapses on
its own and the board is not touched.

### 8.3 Inline editing (calendar)

Daily capture is high-frequency, so the calendar skips the modal entirely.

- Each day row ends with an empty line. Typing into it creates an entry on that
  day. A leading time (`9:30`, `2:30pm`) makes it an event; otherwise it is an
  action. This is the primary capture path.
- Clicking an empty day row focuses a new inline entry on that day. This is how
  future entries are created — there is no date picker flow.
- Actions have a checkbox. Checking one sets `completed_at` and nothing else.
- The "did today" block is a directly editable auto-growing textarea at the foot
  of each day.
- Inline editing covers text only. Day entries carry no images and no folder.

### 8.4 Three surfaces, one save path

The modal, the composer and the full pane edit the same fields and are not
three editors. All three mount the same autosave controller (§8.1) and the
same field partial; only the frame around them differs.

They exist as a set because the ways of arriving want different things. The
composer is the odd one out and the easiest: nothing precedes a new note, so
nothing needs preserving behind it (§8.2a). The other two are a genuine pair,
and want opposite things.
From the board you are usually adding a line to a list you can see — the modal
keeps the board visible behind it and closing returns you to exactly where you
were. From the sidebar you have gone looking for one specific note and intend
to stay in it; a modal there would put a scrim over the tree you just used and
cap the note at a dialog's height.

The rule is where you clicked, not what the note is: a note's length does not
change which surface opens it. Anything else means the same click behaves
differently depending on content, which is not predictable.

### 8.5 Version history (read-only)

Implicit saving with no undo means a note can be gutted and on disk 800ms
later. Trash (§7.5) catches a deleted *note*; it does nothing for a note whose
contents were replaced. History is the answer to that, and it is deliberately
the smallest possible one.

**Read-only. There is no restore.** You can look at an old version and copy
out of it, and that is the entire feature. A restore button would need to
decide what happens to everything changed since, which is a merge question,
and it would make the history a second place a note can be edited from. Select
and copy is a solved interaction that costs nothing to support.

**One version per editing session.** On save, the *previous* body is snapshotted
— but only if the newest existing version is more than ten minutes old, or
there is none. A sitting at the keyboard therefore produces one version, not
one per 800ms debounce, and the slider reads as the note's life rather than as
a keystroke log.

The ten minutes is a gap, not a window: a note edited all afternoon in one
continuous sitting produces one version, and the same note picked up again
after dinner produces a second. What the rule captures is *coming back to a
note*, which is when its contents actually change shape.

**Everything is kept.** Nothing prunes. Session coalescing is what makes that
affordable — a note edited every day for five years is under two thousand rows
of plain text — and an unbounded table of small text rows at this scale (§4)
is cheaper than any retention rule is to reason about.

**In the editor, not a separate view.** A History control in the editor footer
swaps the body for a read-only view of one version, with a range slider above
it and the version's date beside it. The right-hand end of the slider is the
current text, so dragging left is walking backwards through the note. Closing
history returns to the editable body. Because it lives in the shared field
partial (§8.4), the modal, the composer and the full pane all get it.

## 9. Images

Notes only. Day entries and day logs have no attachments.

- Added by dragging files onto the open editor modal, or click-to-upload.
- Stored via Active Storage on local disk. Uploads go direct.
- Displayed as an **ordered gallery below the body text**, not inline.
- Reorderable by drag within the editor. Individually deletable.
- Cards on the board show up to ~3 thumbnails.

### Storage accounting

Per-user total storage is tracked and displayed. **No quotas and no
enforcement** — this is visibility, not a limit. Computed on demand by summing
`byte_size` across the blobs attached to a user's notes; at this scale a scoped
`SUM` is trivially fast and a counter would need maintaining on every attach,
purge and deletion for no benefit.

This matters more than it would otherwise: registration is open (§12) and there
is no ceiling, so this figure is the only signal that disk consumption is
growing faster than intended.

## 10. Reminders (deferred)

Action items and events should eventually surface themselves. Not built now, but
the door is open at near-zero cost:

- Solid Queue ships in the Rails 8 default stack, so recurring jobs already run
  (the trash purge uses one).
- Events already carry `start_minute`, so an event reminder needs only a lead
  time rather than new time modelling.
- Actions have no time. A reminder on an action is a nullable `remind_at`
  datetime — a thing can be filed under a day without wanting to interrupt you
  on it.

Delivery mechanism (email, web push, Android notification) is undecided and
depends on §15.

## 11. Folder filing and manual ordering

- Drag a card from any board onto a folder in the sidebar to file it.
- Drag a note row within the tree to reorder it, or onto another folder to
  refile it. Dragging a folder row reorders the folder list.
- Native HTML5 drag events; no drag library.
- A drop target shows an insertion line for reordering and a filled highlight
  for filing, because "between these two" and "into this" are different
  outcomes and must not look the same mid-drag.
- Reordering writes `position` on the affected rows only, in one transaction,
  scoped through `current_user` so an id from another account is a no-op
  rather than a cross-account write.
- Drop target highlights on hover. Filing is immediate and optimistic, with
  rollback on failure.
- Folder can also be set from within the modal editor.
- Deleting a folder does not delete its notes; they become unfiled.

## 12. Authentication

Email and password. Nothing else, for now. Built on Rails 8's `authentication`
generator: `has_secure_password` (bcrypt) and a per-session `Session` record. No
Devise, no OAuth, no OTP.

**Registration is open.** Anyone who can reach the site can create an account.

**Email verification is not performed.** There is no mail delivery yet, so an
address is accepted as given and `verified_at` stays null. The column exists
from milestone 1 so verification can be applied retroactively. Until mail works,
an address is an unproven string and a mistyped one has no recovery path except
an owner-run console reset.

**Password reset is stubbed.** The full flow is built — routes, token model,
expiry, form — with one substitution: the reset URL is written to the log and
rendered in a flash rather than emailed. Switching to real delivery later is a
change to one mailer, not a new feature.

**Sessions** are per-device database records, so individual devices can be
revoked. 30 days sliding; activity is only written when it is more than an hour
stale, because writing on every request means a SQLite lock.

**Rate limiting** via Rails 8's controller-level `rate_limit`, on sign-in and
registration, per IP.

**Encryption.** Note titles, bodies and images are stored unencrypted. The
database file is readable by anyone with filesystem access to the server — an
accepted tradeoff for a personal app on a machine the owner controls. Passwords
are exempt: bcrypt, never stored recoverably. TLS remains mandatory in
production since sessions traverse the network.

**No deployment coupling.** Email auth imposes no constraint on the hostname —
there are no redirect URIs to register.

## 13. Technical approach

- **Rails 8**, SQLite, Solid Queue and Solid Cache. No Postgres, no Redis.
- **Hotwire** — Turbo Frames for the modal and view swaps, Stimulus for masonry,
  autosave, drag-drop, and scroll anchoring. Importmap; no Node toolchain in dev
  or on the server.
- **Plain CSS with custom properties**, not a utility framework. Named design
  tokens (surface, text, border, radius, spacing) port directly to an Android
  theme, which utility classes do not.
- Native `<dialog>` for the modal — backdrop, Escape handling and focus trapping
  without a library.

## 14. Deployment

- Target: a MacBook Air acting as a home server, on the tailnet.
- Capistrano over SSH.
- **mise** for the runtime. A `.mise.toml` in the repo pins Ruby; `mise install`
  reads that file and nothing else. It shims Ruby on PATH inside the project
  directory and touches nothing else on the machine — no system Ruby replaced,
  no `/usr/local` writes, and removing the project removes the footprint.
  `BUNDLE_PATH` is set to `vendor/bundle` so two apps on the same server can
  never fight over a gem version.
- App runs under launchd, invoked through `mise exec`, behind `tailscale serve`
  for TLS. `assume_ssl` is on and `force_ssl` off, since TLS terminates at the
  proxy.
- SQLite databases and Active Storage blobs live outside the release directory
  (`NOTBUK_DB_PATH` / `NOTBUK_BLOB_PATH`) and survive deploys.
- Backups: nightly SQLite backup plus blob directory to an external location.

**Superseded:** v2 specified Nix with a flake in the repo. Nix on macOS with
native gem extensions has known friction, and the reproducibility it buys is
worth less here than a setup that is trivially understandable and trivially
removable. mise gives per-project pinning with none of that cost.

## 15. Android (phase 2)

Same look and feel as the web app. Two candidates, to be decided before the web
app's controllers are finalised, since one requires a JSON API and the other
does not:

- **Turbo Native shell** — wraps existing web views. Visual parity is exact and
  free; inherits the web session cookie. Days of work. No offline support.
- **Native Compose client against a JSON API** — real offline capability and
  native interaction. Weeks of work. Requires `/api/v1`, a sync strategy and a
  token-issuing endpoint.

The three-object model helps here: `DayEntry` and `DayLog` are small, flat and
plain-text, so they serialise and sync far more easily than a rich-text note
would have.

## 16. Import (final phase)

Keep content migrates via Google Takeout — one JSON file per note with title,
body, timestamps, pinned state, labels and attachment references. Keep labels
become folders. Keep notes all become `Note` records; nothing lands on the
calendar. Scheduled last, so the schema is settled by the time it runs.

## 17. Design principles

- Capture friction is the thing to optimise. Every interaction between a thought
  and it being saved is suspect.
- Dark theme first.
- No confirmation dialogs except for destructive, unrecoverable actions.
- Legible at a glance from across a desk.

## 18. Milestones

| # | Deliverable | Status |
|---|---|---|
| 1 | Rails skeleton, models, migrations, seeds — **including `User` and `user_id` scoping** | ✅ built |
| 2 | Tiled board, card design, masonry, CSS tokens | ✅ built |
| 3 | Editor modal, autosave controller, create-on-keystroke | ✅ built |
| 4 | Sidebar tree — folders, note rows, full-pane note, drag-to-file | |
| 5 | Images — upload, gallery, thumbnails | |
| 6 | Calendar day stream — events, actions, rollover, day log, inline editing | |
| 7 | Auth — email + password, sessions, rate limiting, stubbed reset | |
| 8 | Search, archive, trash | |
| 9 | Tailscale, mise on the server, Capistrano deploy | |
| 10 | Android | |
| 11 | Reminders | |
| 12 | Keep import | |
| 13 | Manual ordering — drag to reorder folders and notes in the tree | |
| 14 | Version history — polymorphic versions, session capture, read-only slider | |

Milestone 2 settles the visual language everything else inherits, so it's worth
over-investing in relative to its size.

**The full-pane note is milestone 4, not 3.** It needs the sidebar to be
reachable, and it reuses milestone 3's autosave controller unchanged — which
is the test of whether that controller was built as a standalone thing (§8.1)
or quietly welded to the modal.

**Manual ordering is milestone 13, not 4.** The sidebar is worth having as soon
as there are folders; hand-arranging it is not worth having until there is
enough in it to be worth arranging. Splitting them keeps `position` and its
first-drag backfill out of the milestone that introduces the tree, and the
`position` column ships with the tree so the later work is a controller and a
drag handler rather than a migration against a populated table.

**Version history is milestone 14, but its schema is settled now** (§8.5).
It is genuinely separable — nothing between here and 13 needs it, and it needs
nothing from them beyond a text body to attach to. The one thing that does not
keep is the shape of the table: notes-only versus polymorphic stops being a
free choice the moment there are rows in it, and milestone 6's day log is a
second caller. Everything else about the feature is additive and can wait.

Its couplings to milestones that come first, all small and all one-directional:
purging a trashed note must take its versions with it (`dependent: :delete_all`,
milestone 8); search does not index versions, because surfacing text you
deleted a year ago as a hit is a bug (8); the Keep import creates no versions,
since Takeout has no history to import and a synthetic "version 1" per note
would be a lie (12).

**The `User` model and `user_id` columns shipped in milestone 1**, even though
sign-in doesn't arrive until 7. Retrofitting ownership across every controller,
query and view later is a far larger job than carrying an unused foreign key for
six milestones. Until milestone 7, seeds create a development user and
`current_user` returns it unconditionally — a stub in the Authentication concern
that milestone 7 deletes without touching anything else.

### What milestone 3 actually shipped

The editor (§8.2) and the autosave controller behind it (§8.1).

`autosave_controller.js` is mounted with a form, a create URL and — once the
record exists — an update URL, and knows nothing else. It debounces 800ms,
saves immediately on blur and on any deliberate change (folder, pin), chains
every request behind the one before it so a slow response cannot land after a
newer one, and flushes on unload and on `turbo:before-visit` with `keepalive`
so a navigation cannot swallow the last keystroke. Milestone 4's full-pane
note mounts this file unchanged; if it needs an edit, it was built wrong.

`composer_controller.js` and `modal_controller.js` are frames and nothing
else, and neither knows anything about saving. The composer expands in place
(§8.2a), treats a click outside, Escape and Done as one act, and on close
refreshes the board and marks the card the note landed in — parked on the
window as a one-shot `turbo:render` listener, since the element that asked for
the mark is gone by the time the board has re-rendered. If nothing was typed,
it collapses without touching the board.

`modal_controller.js` is the frame and nothing else: a native `<dialog>`,
`showModal` on connect, backdrop click and Escape and Close all routed to the
same `close` event. Both controllers sit on the same element, because `input`,
`change` and `focusout` bubble to the dialog while `close` does not bubble at
all — one element is the only place that sees every one of them.

**The board refreshes on close, not on save.** Closing revisits the board's
own URL, which Turbo treats as a page refresh and — with `turbo-refresh-method:
morph` in the layout — patches rather than rebuilds. Replacing the card in
place instead would leave the board sorted wrongly, since editing a note is
exactly what moves it to the front under "last edited". The refresh is
triggered by `autosave:finalized`, not by the close event, so it cannot render
the note as it was before the last save landed.

**Endpoints answer JSON, not Turbo Streams.** They are called by a fetch, never
by a form submission, and what the client needs back is where to send the next
save. A stream response would make the save path depend on the surface that
issued it, which is the coupling §8.1 exists to prevent.

**`DELETE /notes/:id` is discard, not delete.** It refuses anything that is not
`Note#empty?`, so the one case it serves — a note created on the first
keystroke and emptied out again before the editor closed — is served, and an
autosave bug can cost a keystroke but never a note. Getting rid of a note the
user still has content in is milestone 8's trash, through `deleted_at`.

Cards are `<article>`s wrapping a link that covers them, rather than links:
milestone 4 makes the card a drag source, and a draggable link drags its href.

The fields live in one partial (`notes/_fields`) that knows nothing about the
surface it is on; the dialog and the composer are wrappers around it. Milestone
4's full pane is a third wrapper, which is the cheapest possible version of
§8.4 — and the thing that stops the pane becoming a second editor.

Not in this milestone: images (5), the full-pane note (4), archive and trash
(8).

### What milestone 2 actually shipped

The tiled board at `root`: design tokens, note cards, and masonry as a grid of
1px rows with a computed span per card. Sort (edited or created, either
direction) is URL state rather than session state. The type scale is sized per
role — 18px card body as the base, 22px titles, 15px chrome, 13px metadata,
12px section labels — rather than one size multiplied, so metadata does not
grow in step with the text being read. The milestone 1 smoke-test page and its
controller are gone. Notes are read-only until milestone 3.

The sidebar is **not** in milestone 2. The board shell reserves no space for
it; milestone 4 introduces the two-column shell.

### What milestone 1 actually shipped

Schema and models for `User`, `Session`, `Folder`, `Note`, `DayEntry`,
`DayLog`, plus the `Day`/`Year` composers and a `PurgeTrashedNotesJob` wired
into Solid Queue's recurring schedule. Seeds include a **second account whose
content is labelled `LEAK CANARY`** — if one ever appears in the interface, a
query has escaped `current_user`. `test/models/isolation_test.rb` asserts the
property directly.

Runtime as built: Ruby 3.4.10, Rails 8.1.3.1, Bundler 2.6.9, 68 tests.

## 19. Open questions

1. **Mail delivery.** Deferred. Password reset is stubbed until this exists.
   Needed before milestone 9 if anyone other than the owner is expected to
   recover an account unaided.
2. **Tailnet configuration.** Deferred, not blocking. MagicDNS and HTTPS certs
   are wanted for TLS before milestone 9.
3. **Storage visibility surface.** Is a plain settings figure enough, or is a
   small owner-facing view across all users wanted?
4. **Completed actions on a past day.** Once a day is in the past, should its
   completed actions stay visible in the stream or collapse into a count? Only
   matters once there is enough history to scroll through.
5. **Search across types.** §7.4 says results are grouped by type. Whether a
   day entry hit should link into the calendar at that day, or open something
   modal, is undecided until milestone 8.
6. **Solid Queue / Cache / Cable schemas.** `db/cache_schema.rb`,
   `db/queue_schema.rb` and `db/cable_schema.rb` do not exist yet, so those
   three databases are empty. Development is unaffected (memory store, async
   adapter) but production config points at them and milestone 9 needs them
   generated.
