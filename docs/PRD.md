# noted — product requirements

**Status:** v15 — the calendar is one text document per year
**Owner:** single user (self-hosted)
**Last updated:** 3 Sep 2026

---

## 0. What changed since v13

The calendar was specified as records — a `DayEntry` row per line, a `DayLog`
row per day, an inline editor per field. Prototyping showed the practice it was
modelling is text, and that the operations that matter (move a task to a future
day, cut a week, undo a bad edit) are text operations that records make
expensive.

**A year is now one plain-text document.** Dates are syntax, not structure.
`DayEntry` and `DayLog` are gone. The reasoning and the rejected alternatives
are ADR 0005; this document carries what the decision means for the product.

Notes are unaffected. The Note model, §6, §7.1, §7.3, §7.6, §7.7, §8.2, §9 and
§11 stand as written in v13.

---

## 1. Summary

A self-hosted personal application replacing Google Keep, with a calendar and a
daily log alongside it. Rails web app deployed to a home server, followed by an
Android client sharing the same visual language.

- **Notes** — undated, browsed as a tiled board. Groceries, packing lists, book
  lists, fragments. A note *cannot* be scheduled to a day.
- **Calendar** — one text document per year, read newest-first, edited
  directly. A day is the span of text under a date line.

## 2. Goals

- Own the data. No third-party service, no export anxiety.
- Match Keep's speed of capture — open, type, close, saved.
- Make a year of days scannable and navigable in a way a calendar app isn't.
- Keep a record of what was actually done, not only what was planned.
- **Make moving a task to a future day cost nothing.** The one workflow a paper
  diary cannot do, and the reason the calendar exists.
- Single codebase of visual tokens shared between web and Android.
- Deployment that doesn't pollute the host machine and is reproducible months
  later.

## 3. Non-goals

- Sharing, collaboration, or permissions *between* users. Multi-account, not
  multi-player.
- Encryption of note contents at rest. Bodies and titles are plaintext in SQLite.
- Markdown or rich text. A statement about storage, not rendering: the calendar
  has syntax (date lines, `done`, `[[…]]`, deferral markers) that is styled on
  screen. The test is that the file on disk reads as something a person typed.
- Per-note colours. Folders are the only organising axis.
- Real-time sync between concurrent clients (last write wins is acceptable).
  **Revisited for offline clients** — this was written about two browsers on
  one tailnet, not a phone that has been offline for a day. See ADR 0001 §6.
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
| `password_digest` | string | unused; sign-in is federated (ADR 0003) |
| `auth_sub` | string | auth's subject claim — the identity of record |
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
| `deleted_at` | datetime, nullable | Trash (soft delete). Retained until manually emptied. |
| `position` | integer, nullable | Manual order in the sidebar tree |
| `board_position` | integer, nullable | Manual order in the All Notes masonry board |
| `folder_board_position` | integer, nullable | Manual order in the current folder's masonry board |
| images | Active Storage `has_many_attached` | Ordered |

No date column of any kind.

`position`, `board_position`, and `folder_board_position` are deliberately
separate. The sidebar tree is folder-local, All Notes has one masonry sequence,
and each folder board has its own masonry sequence. Pinned and unpinned notes are
separate board zones, and dragging cannot move a card across that boundary.

A null `position` is unordered in the tree, and unordered notes sort after
positioned ones by title. A null `board_position` falls back to edited order
until the first All Notes drag writes the visible sequence; a null
`folder_board_position` falls back to `board_position` and then edited order
until the first folder-board drag.

### YearDoc — the whole calendar

| Field | Type | Notes |
|---|---|---|
| `user_id` | fk, not null | Owner |
| `year` | integer, not null | Unique per user |
| `body` | text | The whole year. Plain text. |

That is the entire calendar schema.

A **day** is the span between one line matching the date pattern and the next.
An **entry** is a line. `done` at the end means completed; a leading time makes
it an event; anything else is an action. Nothing has an id.

**Ordering is newest-first.** The document reads downwards into the past.

The v13 split between entries (planned) and a day log (what happened) is gone.
It was justified on the grounds that the two are written at different times with
different rhythms, and the log this replaces never made that distinction — it is
one list of lines per day, some of which get `done` appended.

### The derived index

Search, reminders and backlinks need structure the text doesn't carry. That
structure is **derived, never authoritative**: parsed out of `YearDoc#body` on
write, rebuildable from scratch. If the index and the text disagree, the text is
right.

At least `(user, date, line_no, kind, text, done)` for entries and
`(user, date, target)` for links.

### Where v13's columns went

| v13 | v15 |
|---|---|
| `DayEntry#start_minute` | a leading time in the line, parsed on demand |
| `DayEntry#completed_at` | `done` at the end of the line |
| `DayEntry#position` | the order of lines in the document |
| `DayEntry#deleted_at` | deleted text; trash does not cover the calendar |
| `DayLog` | the same lines under the same date |
| action rollover query | a scan for undone lines before today (§20) |

### Version — read-only history of a text body

| Field | Type | Notes |
|---|---|---|
| `record_type` | string, not null | `"Note"` today, `"YearDoc"` at milestone 6 |
| `record_id` | fk, not null | The thing this is a version of |
| `title` | string, nullable | Null for records that have no title |
| `body` | text | The body **as it was before** the save that displaced it |
| `created_at` | datetime | When that content stopped being current |

**Polymorphic from the start.** A `note_versions` table would be simpler and
would be wrong within one milestone: the calendar (§7.2) is free text edited
with exactly the same implicit-save rhythm and wants exactly the same history.
One extra column now costs nothing; adding it to a populated table later is a
migration nobody wants to write.

A `YearDoc` version stores **the whole document**, not a diff. A year is a few
tens of KB, so history is a series of complete, readable years.

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
| `name` | string | Not unique — a folder is identified by its id (UUID), not its name |
| `position` | integer | Manual ordering in the left rail |

Flat — no nesting. Folders apply to notes only; the calendar is not foldered.
Revisit only if the flat list exceeds ~15 entries in practice.

**Identity is a UUID.** Every table has a string (UUID) primary key, minted by
whoever creates the record — including an offline client, which generates its
own id and the server keeps it unchanged, so nothing rewrites ids on sync
(ADR 0002).

### Days are not a table

Still true, and now more so: a day is not an object at all. It is a span of
text, found by scanning for the pattern. Nothing stores it and nothing has an
id, so `Day` and `Year` as row-composing Ruby objects go with the rows.

### Scoping rule

Every query originates from `current_user` — `current_user.notes`,
`current_user.year_docs`, `current_user.folders`. Nothing is ever loaded by
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
│ ────────────       │      board / calendar        │
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
the tree — days are not filed and never appear as rows. They can, however,
*point* at notes (§19).

## 7. Views

### 7.1 Tiled board (P0)

Masonry grid of note cards, Keep-style.

- Cards show title, body clamped to ~12 lines, and a thumbnail strip if the note
  has images.
- Pinned section above the rest.
- Cards are manually ordered by drag within their pinned or unpinned section.
- Card ordering must read left-to-right, top-to-bottom, so column-flow masonry
  (CSS `columns`) is unacceptable. Use a grid with computed row spans.
- Cards are drag sources for folder filing.

### 7.2 Calendar — one document (P0)

A single editor filling the main pane, holding one year.

- **Newest first.** Scrolling up moves forward in time.
- **Today always has a section**, created on load if absent, and the view opens
  with it at the top of the viewport. Anything scheduled ahead is above.
- **Date lines** (`12 sep`) are headings: weekends tinted, today accented,
  locked against editing (§8.3).
- **A month calendar is pinned top-right, outside the document.** Whole month
  shown, today ringed, days that already have a section brighter. Clicking any
  day inserts that date line **at its correct position in the document**,
  wherever that is; if the date already exists it jumps there instead.
- **Empty days between two written days** render as a dim inline strip of
  clickable dates, Sundays red, at 40% until hovered. **Provisional** — the
  panel now does everything they do, and they are the only remaining thing in
  the stream that isn't the writer's text. See §20.
- Year from a dropdown in the header, which also shows the month of whatever is
  at the top of the viewport.

Empty days are **shortcuts, not records**. Clicking one types characters, and
lands in undo history identically to having typed them.

### 7.3 Folder view (P0)

Identical to the tiled board, filtered to one folder.

### 7.4 Search (P1)

Header search box. Full-text over note titles/bodies and `YearDoc` bodies via
SQLite FTS5. Results grouped by type. A calendar hit resolves to a year and a
date, so the editor opens scrolled to that day. Versions are not indexed.

### 7.5 Archive and trash (P1)

**Notes only.** Archive applies to notes, and so does trash: a soft delete
retained until it is manually emptied, nothing purging it on a timer (ADR 0002).

There is no soft delete in the calendar. Deleted text is deleted, and version
history (§8.5) is what protects it. A deliberate reduction from v13 — a trash
for text spans has no coherent restore semantics.

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
- The markup is a list of links and buttons, deliberately not `role="tree"`.
  Real tree semantics promise arrow-key navigation, typeahead and a roving
  tabindex, and a half-implemented tree is worse to a screen reader than an
  honest list — which is already keyboard-reachable in source order. If the
  tree grows to the depth where that promise is worth keeping, keep it
  properly.
- **Folders are created, renamed and deleted here and nowhere else.** A new
  folder is a field at the foot of the list, so making one is typing a name
  and pressing return. Renaming swaps the row for a form in place. Deleting
  unfiles its notes (§11) and is the one control in the interface that
  confirms, because it is the only one whose effect is not visible on screen
  afterwards.

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
- Its own URL, so a note is linkable and the back button works. Sidebar links
  and the modal's expand control use it. Board cards do not navigate: the board
  preloads their complete note data and opens one JavaScript-populated dialog,
  so opening a modal has no request latency. The card link remains the
  no-JavaScript fallback to the full pane.
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

For the calendar this is one document save rather than per-record autosave. At a
few tens of KB that is cheaper than the request-per-keystroke design it
replaces.

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

**On close the note takes its place on the board and is marked there.** A new
note goes to the front of its pinned or unpinned board section, and the card it
landed in is highlighted, focused and scrolled to. A board can be a few hundred
cards; a note that drops into one unannounced has to be found again, which
undoes the capture speed the composer exists for (§17). The mark lasts until the
next render, which is as long as the question does.

If nothing was typed, nothing was created (§8.1), so the composer collapses on
its own and the board is not touched.

### 8.3 Calendar editing

CodeMirror 6 over a plain-text document with a decoration layer. Rationale,
rejected alternatives and the two constraints that cost a day each are ADR 0005.

- **Typing is the only capture path.** No modal, no per-line controls.
- **`Tab` / `Shift-Tab`** jump between date headings.
- **`Alt-↑` / `Alt-↓`** move a line; crossing a date heading is how a task
  changes day. Date headings themselves do not move.
- **Typing `/` opens an inline command input at the cursor.** The slash lives
  inside the input, so arguments can contain spaces; a `↵` icon says Enter
  applies. It can open on an entry, a blank line, or a date heading. Escape
  leaves the slash as literal text on editable lines; Backspace on a bare slash
  closes the input.
- **First commands:** `/done`, `/not doing`, `/fail`, `/urgent`,
  `/schedule at 9pm`, `/schedule call sam at 9pm on 12 sep`, `/move to 2 days`,
  `/move to 12 sep`, `/remind-over-days`. They rewrite the current line, move it
  to another day, or create a dated line directly; none store side data.
- **Date lines are locked.** Not typable into; not deletable while their day has
  content. A refused edit flashes the line — silence reads as a broken editor.
- **Cut, copy, paste, undo and redo are the editor's.** This is most of the
  value.
- The empty-day strips are block widgets, so they are not in the document and
  cannot leak into a copy, a save, or a search.
- Calendar editing covers text only. No images, no folder.

### 8.4 Three surfaces, one save path

The modal, the composer and the full pane edit the same fields and are not
three editors. All three mount the same autosave controller (§8.1) and the
same field partial; only the surface around them differs.

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

**A `YearDoc` version is the whole year**, which a note's version already is for
a note. No diffs, no merge question, no per-record history to scope.

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

Notes only. The calendar has no attachments.

- Added by dragging files onto the open editor modal, or click-to-upload.
- Stored via Active Storage on local disk. Uploads go direct.
- Displayed as an **ordered gallery below the body text**, not inline.
- Reorderable by drag within the editor. Individually deletable.
- Cards on the board show up to ~3 thumbnails.

### Storage accounting

Per-user total storage is tracked and displayed. **No quotas and no
enforcement** — this is visibility, not a limit. Computed on demand by summing
`byte_size` across the blobs attached to a user's notes; at this scale a scoped
`SUM` is trivially fast and a counter would need maintaining on every attach and
deletion for no benefit.

This matters more than it would otherwise: registration is open (§12) and there
is no ceiling, so this figure is the only signal that disk consumption is
growing faster than intended.

## 10. Reminders (deferred)

Action items and events should eventually surface themselves. Not built now.

A reminder reads the derived index (§5), not a table of records. Solid Queue
already runs recurring jobs. A leading time in a line is an event's time.

Can a reminder time live in the line's own text? If not, the derived index needs
to be writable, which breaks "derived and disposable" (§20).

Delivery mechanism (email, web push, Android notification) is undecided and
depends on §15.

## 11. Folder filing and manual ordering

- Drag a card from any board onto a folder in the sidebar to file it.
- Drag a board card over another card to reorder it within its pinned or
  unpinned section.
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

**Superseded by ADR 0003.** noted holds no passwords. Sign-in is federated to
the fleet's `auth` service over OIDC: `auth` is the only thing that talks to
Google, owns the allowlist, and can revoke a person across every app at once.
noted is a client of it.

What that leaves in this app: an account row keyed by auth's `sub`, a
first-party session cookie scoped to noted's own host, bearer verification on
`/api/v1` against auth's published JWKS, and an endpoint auth can POST to when
a session is to be killed. Registration, verification and password reset are
not noted's concerns and their surfaces do not exist here. `password_digest`
survives as a nullable column rather than a migration; nothing writes it.

**Development runs against a stub issuer**, not against auth: fixture
identities in `config/dev_users.yml`, a picker on the sign-in page, and tokens
signed with a checked-in keypair that go through the same `TokenVerifier` as
production. `AUTH_MODE=oidc AUTH_ISSUER=http://localhost:3001` swaps in the
real provider; `AUTH_MODE=stub` refuses to boot outside development and test.

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
- **Hotwire** — Turbo Frames for the composer and view swaps; Stimulus for the
  preloaded note modal, masonry, autosave, drag-drop, scroll anchoring, and the
  CodeMirror calendar wrapper. Importmap; no Node toolchain in dev or on the
  server.
- **CodeMirror 6, vendored.** Bundled with esbuild on a laptop, committed to
  `vendor/javascript`, pinned in the importmap. No Node on the server.
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
  (`NOTED_DB_PATH` / `NOTED_BLOB_PATH`) and survive deploys.
- Backups: nightly SQLite backup plus blob directory to an external location.

**Superseded:** v2 specified Nix with a flake in the repo. Nix on macOS with
native gem extensions has known friction, and the reproducibility it buys is
worth less here than a setup that is trivially understandable and trivially
removable. mise gives per-project pinning with none of that cost.

## 15. Native clients and the API — decided

*Recorded as `docs/ADR/0001`, which carries the reasoning, the rejected
alternatives, and the implementation plan — the endpoints and the order of
work. This section is what the decision means for the rest of this document.*

**Native clients on both desktop and mobile — SwiftUI on macOS, Compose on
Android — against a JSON API.** The API sits beside the HTML surface rather
than beneath it: the web app goes on rendering server-side with Hotwire (§13),
and both surfaces stand on the same models, so ownership (§5), the
folder-belongs-to-the-same-user validation, `Note#empty?` and the discard rule
are enforced once. Reads are HTML and writes are JSON, the browser included.

Consequences for this document:

- **Every feature from here ships its JSON with its HTML.** Notes and folders
  predate the decision and owe one catch-up slice.
- **Authentication (§12) serves both surfaces.** Whatever authenticates a
  browser session must issue a client credential from the same `Session`
  record, or there are two authentication systems. Nothing before that exists
  is protected on either surface.
- **Deletion has to leave a trace for synced records.** A client holding its own
  copy cannot tell a deleted record from one it was never sent, so `Folder`
  needs the `deleted_at` that `Note` already has. The calendar is one document;
  deleted lines are protected by `Version`, not tombstones.
- **A cookie-authenticated API needs CSRF protection; a token-authenticated
  one does not.** `ActionController::API` does not verify authenticity tokens,
  which is correct for a native client sending a bearer token and unsafe for a
  browser sending a session cookie. Since the browser is a caller (ADR 0001),
  native clients authenticate by token, and the browser's own calls verify CSRF.
- **Sync is open.** §3's "last write wins is acceptable" was written about two
  browsers on one tailnet. ADR 0001 §6 argues that a losing write
  should become a `Version` (§8.5) rather than nothing, which is the cheapest
  answer available and uses a feature already planned.

**The calendar's API is one document.** `GET /api/v1/years/2026` returns text;
`PUT /api/v1/years/2026` replaces it. No per-entry endpoint, ever.

**Conflict is a text merge, not a lost row.** Two clients editing different days
of one year is now a document-level conflict where v13 had none. Mitigations in
order: base-version check rejecting stale writes; three-way line merge, which
text supports well; losing write becomes a `Version`.

## 16. Import (final phase)

The existing log file is the first import and nearly free: it is already this
format. Normalising date lines is the whole job.

Keep content migrates via Google Takeout — one JSON file per note with title,
body, timestamps, pinned state, labels and attachment references. Keep labels
become folders. Keep notes all become `Note` records; nothing lands on the
calendar.

## 17. Design principles

- Capture friction is the thing to optimise. Every interaction between a thought
  and it being saved is suspect.
- Dark theme first.
- No confirmation dialogs except for destructive, unrecoverable actions.
- Legible at a glance from across a desk.
- **The document is the truth.** Nothing is stored that the writer didn't type.
  Anything else is derived and disposable.

## 18. Milestones

| # | Deliverable | Status |
|---|---|---|
| 1 | Rails skeleton, models, migrations, seeds — **including `User` and `user_id` scoping** | ✅ built |
| 2 | Tiled board, card design, masonry, CSS tokens | ✅ built |
| 3 | Editor modal, autosave controller, create-on-keystroke | ✅ built |
| 4 | Sidebar tree — folders, note rows, full-pane note, drag-to-file | ✅ built |
| 5 | Images — upload, gallery, thumbnails | |
| 6 | **Calendar — `YearDoc`, CodeMirror editor, syntax, panel** | prototyped |
| 7 | Auth — OIDC client of `auth`, sessions, bearer API (ADR 0003) | ✅ built |
| 8 | Search, archive, trash | |
| 9 | Tailscale, mise on the server, Capistrano deploy | |
| 10 | Android — Compose client against /api/v1 | |
| 11 | Reminders | |
| 12 | Keep import | |
| 13 | Manual ordering — drag to reorder folders, sidebar notes and board cards | ✅ built |
| 14 | Version history — polymorphic versions, session capture, read-only slider | |
| 15 | macOS — SwiftUI client against /api/v1 | |
| 16 | API catch-up — notes and folders over /api/v1, shared scoping concern, autosave repointed | ✅ built |
| 19 | **Linking — `[[…]]`, resolution, backlinks** | |
| 20 | **Task overflow — push command, markers, rollover** | |

Milestone 2 settles the visual language everything else inherits, so it's worth
over-investing in relative to its size.

**Manual ordering is milestone 13, not 4.** The sidebar is worth having as soon
as there are folders; hand-arranging it is not worth having until there is
enough in it to be worth arranging. Splitting them kept the tree controller out
of the milestone that introduced the tree. Board ordering later added
`board_position` rather than reusing the tree's `position`.

**Version history is milestone 14, but its schema is settled now** (§8.5).
It is genuinely separable — nothing between here and 13 needs it, and it needs
nothing from them beyond a text body to attach to. The table stays polymorphic:
the calendar's `YearDoc` is a second caller, and a year version stores the whole
body. Everything else about the feature is additive and can wait.

Its couplings to milestones that come first, all small and all one-directional:
destroying a note must take its versions with it (`dependent: :delete_all`);
the only path that destroys one now is discarding an empty note (ADR 0002); search does not index versions, because surfacing text you
deleted a year ago as a hit is a bug (8); the Keep import creates no versions,
since Takeout has no history to import and a synthetic "version 1" per note
would be a lie (§16).

Milestone 6 is much smaller than in v13 — one table, one column, one editor —
and milestone 20 carries what was cut out of it.

**Every milestone from 5 ships JSON with its HTML** (§15). The API is a
parallel namespace over the same models, not a layer beneath the web app, and
the rule that keeps it honest is that domain logic lives in models: a JSON
caller and an HTML caller must not be able to reach different outcomes. Notes
and folders owe a one-time catch-up slice, since they were built before the
decision. Bearer verification arrived with milestone 7, which is where sessions
became real for both surfaces at once.

**The `User` model and `user_id` columns shipped in milestone 1**, even though
sign-in doesn't arrive until 7. Retrofitting ownership across every controller,
query and view later is a far larger job than carrying an unused foreign key for
six milestones. Milestone 7 deleted the stub that returned the seeded user
unconditionally, and `current_user` became the account behind a session or a
bearer token, without touching anything downstream of it.

## 19. Linking notes and days

`[[…]]` in the calendar refers to a note, so a day can point at the packing list
rather than restating it.

- **A link carries the note's UUID; the title is resolved and rendered at
  runtime.** Renaming never breaks a link and never rewrites text the writer
  typed. The cost is accepted: this is the one place the raw document is not
  fully readable on its own, and it buys correctness on duplicate titles and
  renames, both of which break immediately otherwise.
- Styled by decoration, like date lines and `done`.
- The `(user, date, target)` link table is part of the derived index (§5).
- Backlinks — "this note is mentioned on these days" — fall out of the index
  and should ship with it.
- A link does not date a note. §3's non-goal stands.
- **Autocomplete on `[[` is required, not optional.** Nobody types a UUID. This
  likely puts `@codemirror/autocomplete` in the bundle.

## 20. Task overflow — the reason for building this

When a task is not done on the day it was scheduled, it moves to a future date.
Today that is cut and paste, which works and costs nothing to build.

What it cannot do is leave a trace, because a line has no identity. The design
for getting one:

**The trace lives in the line.** A task that has slid twice reads:

```
call the plumber ↩ 21 aug ×2
```

The marker holds the date it was *first* scheduled and how many times it has
moved. Because the history is part of the line's text, it travels through cut,
paste and undo automatically — no ids, no index to keep in sync. Rendered dim
and small by decoration; the inline date is clickable and jumps to that day.
Deletable by hand, which forgives a task its history.

**Recorded only when the app performs the move.** Two entry points:

1. `Alt-↑`/`Alt-↓` — after the swap, if the governing date heading changed,
   rewrite the marker in the same transaction.
2. A slash move command — `/move to 2 days`, `/move tomorrow`,
   `/move to 12 sep` — deletes at origin, creates the target date if needed,
   and inserts there. One transaction, one undo.

**Cut-and-paste can also be caught, with limits.** A `cut` handler can write a
private MIME type into the `DataTransfer` alongside `text/plain`, carrying each
line's origin date — which the plain text cannot, since the date heading is not
part of the selection. On paste, compare a hash of the plain text against the
payload; if they disagree the content was edited in between, so drop the
metadata and paste plainly. Limits: it only works within one browser, never
across apps or to a native client; copy is not a move; same-day pastes must be
excluded or reordering inflates counters; and a pasted block containing date
headings is a day being moved, not a task being deferred.

**Build the command first.** It is simpler and it answers whether the trace is
worth having at all. If it is, the clipboard version is how it catches the habit
you actually have.

**Rollover falls out of this.** Once markers exist, "what's still open from past
days" is a scan for undone lines dated before today.

**The count is the signal, not the trace.** A line wearing `×4` is not a task;
it is a project, or it is a lie. Design the rendering to make high counts
visible rather than tidy.

## 21. Open questions

1. **Do the in-between strips survive?** The pinned panel does everything they
   do, from a fixed position, without moving text. They are the last thing in
   the stream that is not the writer's words, and the one piece that cannot
   cross to Compose. Decide by living with the panel for a week.
2. **What happens when a linked note is trashed or archived?** The link still
   resolves; pointing at something filed away needs a rendering answer.
3. **Do days get linked too** — `[[12 sep]]` from a note, or day to day? If so,
   the push command could write its trail as ordinary links.
4. **Where does a link open?** The old rule is that the surface follows where
   you clicked. From the calendar, modal or full pane?
5. **Does note text get syntax too**, or is syntax calendar-only?
6. **Can a reminder time live in the line's own text?** If not, §5's index needs
   to be writable, which breaks "derived and disposable".
7. **Concurrent edits** to one year from two devices. Is a base-version check
   enough for one person with two machines?

Settled: links carry UUIDs with titles rendered at runtime; the `## ongoing`
and `## next cohort` lanes become an ordinary note rather than a second syntax;
a task crossing a year boundary is handled by hand (cut, switch year, paste);
Android is per-day native fields.

## 22. Known gaps in the prototype

Not design questions — things `calendar-prototyping/stream-text.html` does not
do yet.

- Switching years does not save. The dropdown replaces the document. The
  year-boundary workflow depends on fixing this.
- No persistence of any kind.
- `Mod-Enter` will append `done` to a date line if the cursor is on one.
- Dragging text onto a strip or the panel is untested.
- `@codemirror/search` is not bundled, so `Mod-f` and `Mod-d` do nothing. For a
  document that is a whole year this is the largest missing affordance.
- Slash command grammar is deliberately small: no suggestions, no fuzzy match,
  no natural-language date parser beyond the examples in §8.3.
