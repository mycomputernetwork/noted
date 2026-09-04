# noted — product requirements

**Status:** v15 — final for this round. Calendar is one text document per year.
**Owner:** single user (self-hosted)
**Last updated:** 3 Sep 2026

Companion documents: `calendar-as-text.md` (mechanism and rejected
alternatives), `stream-text.html` (working prototype).

---

## 0. What changed since v13

The calendar was specified as records — a `DayEntry` row per line, a `DayLog`
row per day, an inline editor per field. Prototyping showed the practice it was
modelling is text, and that the operations that matter (move a task to a future
day, cut a week, undo a bad edit) are text operations that records make
expensive.

**A year is now one plain-text document.** Dates are syntax, not structure.
`DayEntry` and `DayLog` are gone.

Notes are unaffected. §5.1, §6, §7.1, §7.3, §7.6, §7.7, §8.2, §9 and §11 stand
as written in v13.

---

## 1. Summary

A self-hosted personal application replacing Google Keep, with a calendar and a
daily log alongside it. Rails web app on a home server, then an Android client
sharing the same visual language.

- **Notes** — undated, browsed as a tiled board. Groceries, packing lists,
  book lists, fragments.
- **Calendar** — one text document per year, read newest-first, edited
  directly. A day is the span of text under a date line.

## 2. Goals

- Own the data. No third-party service, no export anxiety.
- Match Keep's speed of capture — open, type, close, saved.
- Make a year of days scannable in a way a calendar app isn't.
- Keep a record of what was actually done, not only what was planned.
- **Make moving a task to a future day cost nothing.** The one workflow a paper
  diary cannot do, and the reason the calendar exists.
- Shared visual tokens between web and Android.
- Deployment that doesn't pollute the host and is reproducible months later.

## 3. Non-goals

- Sharing or collaboration between users.
- Encryption at rest.
- **Rich text.** A statement about storage, not rendering: the calendar has
  syntax (date lines, `done`, `[[…]]`, deferral markers) that is styled on
  screen. The test is that the file on disk reads as something a person typed.
- Per-note colours; folders are the only organising axis for notes.
- Tags as a separate axis from folders.
- Offline-first web app.
- **Dating a note.** A note is reached from a day by reference (§19), never by
  being filed on it.

## 4. Users and scale

The owner plus family, over Tailscale, each a private workspace. Low thousands
of notes, low hundreds of images, one calendar document per user per year of a
few tens of KB.

## 5. Data model

### 5.1 Notes — unchanged from v13

`User`, `Session`, `Note`, `Folder`, `Version`. UUID primary keys minted by
whoever creates the record, including offline clients. Every query originates
from `current_user`. Image blobs inherit scoping through their parent note.

### 5.2 YearDoc — replaces DayEntry and DayLog

| Field | Type | Notes |
|---|---|---|
| `user_id` | fk, not null | Owner |
| `year` | integer, not null | Unique per user |
| `body` | text | The whole year. Plain text. |

That is the entire calendar schema.

A **day** is the span between one line matching the date pattern and the next.
An **entry** is a line. `done` at the end means completed; a leading time makes
it an event; anything else is an action. Nothing has an id.

The v13 split between entries (planned) and a day log (what happened) is gone —
the log this replaces never made that distinction.

**Ordering is newest-first.** The document reads downwards into the past.

### 5.3 The derived index

Search, reminders and backlinks need structure the text doesn't carry.
That structure is **derived, never authoritative**: parsed out of
`YearDoc#body` on write, rebuildable from scratch. If index and text disagree,
the text is right.

At least `(user, date, line_no, kind, text, done)` for entries and
`(user, date, target)` for links.

### 5.4 Version

Polymorphic over `Note` and `YearDoc`, as v13 anticipated. A `YearDoc` version
stores **the whole document**, not a diff — a year is small enough that history
is a series of complete, readable years. Session coalescing unchanged: one
version per sitting, ten minutes of quiet ends a sitting.

### 5.5 Where v13's columns went

| v13 | v15 |
|---|---|
| `DayEntry#start_minute` | a leading time in the line, parsed on demand |
| `DayEntry#completed_at` | `done` at the end of the line |
| `DayEntry#position` | the order of lines in the document |
| `DayEntry#deleted_at` | deleted text; trash does not cover the calendar |
| `DayLog` | the same lines under the same date |
| action rollover query | a scan for undone lines before today (§12) |

## 6. Information architecture

Unchanged. Persistent left sidebar on every view: Notes, Calendar, folder tree
with unfiled notes at its root, then Archive and Trash. Day entries are never
filed and never appear in the tree — but they can now *point* at notes (§19).

## 7. Views

7.1 tiled board, 7.3 folder view, 7.6 sidebar tree, 7.7 full-pane note:
**unchanged from v13.**

### 7.2 Calendar — one document (P0, revised)

A single editor filling the main pane, holding one year.

- **Newest first.** Scrolling up moves forward in time.
- **Today always has a section**, created on load if absent, and the view opens
  with it at the top of the viewport. Anything scheduled ahead is above.
- **Date lines** (`12 sep`) are headings: weekends tinted, today accented,
  locked against editing (§8.3).
- **A month calendar is pinned top-right, outside the document.** Sunday-first,
  whole month shown, today ringed, days that already have a section brighter.
  A 4×3 block of month names above it switches months. Clicking any day
  inserts that date line **at its correct position in the document**, wherever
  that is; if the date already exists it jumps there instead.
- **Empty days between two written days** render as a dim inline strip of
  clickable dates, Sundays red, at 40% until hovered. **Provisional** — the
  panel now does everything they do, and they are the only remaining thing in
  the stream that isn't the writer's text. See §20.
- Year from a dropdown in the header, which also shows the month of whatever is
  at the top of the viewport.

Empty days are **shortcuts, not records**. Clicking one types characters, and
lands in undo history identically to having typed them.

### 7.4 Search (P1)

FTS5 over note titles/bodies and `YearDoc` bodies. A calendar hit resolves to a
year and a date so the editor opens scrolled to it. Versions are not indexed.

### 7.5 Archive and trash (P1)

**Notes only.** There is no soft delete in the calendar — deleted text is
deleted, and version history is what protects it. A deliberate reduction from
v13: a trash for text spans has no coherent restore semantics.

## 8. Editing

### 8.1 Shared behaviour

Implicit save, debounced ~800ms and on blur. No interaction may lose data. For
the calendar this is one document save rather than per-record autosave; at a
few tens of KB that is cheaper than the request-per-keystroke design it
replaces.

### 8.2 Note editing — unchanged

Modal from a board card, in-place composer for a new note, full pane from the
sidebar. Three surfaces, one save path, one field partial.

### 8.3 Calendar editing

CodeMirror 6, plain-text document, decoration layer. Rationale and rejected
alternatives in `calendar-as-text.md`.

- **Typing is the only capture path.** No modal, no per-line controls.
- **`Tab` / `Shift-Tab`** jump between date headings.
- **`Alt-↑` / `Alt-↓`** move a line; crossing a date heading is how a task
  changes day. Date headings themselves do not move.
- **Typing `/` opens an inline command input at the cursor.** The slash lives
  inside the input, so arguments can contain spaces; a `↵` icon on the input
  says Enter applies the command. It can open on an entry, a blank line, or a
  date heading. Escape leaves the slash as literal text on editable lines;
  Backspace on a bare slash closes the input.
- **First commands:** `/done`, `/not doing`, `/fail`, `/urgent`,
  `/schedule at 9pm`, `/schedule call sam at 9pm on 12 sep`,
  `/move to 2 days`, `/move to 12 sep`, `/remind-over-days`. They rewrite the
  current line, move it to another day, or create a dated line directly; none
  store side data.
- **Date lines are locked.** Not typable into; not deletable while their day
  has content. A refused edit flashes the line — silence reads as a broken
  editor.
- **Cut, copy, paste, undo and redo are the editor's.** This is most of the
  value.
- Strips are block widgets, so they are not in the document and cannot leak
  into a copy, a save, or a search.

**Commands that write date lines bypass the lock.** `insertDate`, the
abbreviation expander and the line-mover all produce changes the filter would
refuse. The prototype raises a module-level flag around `dispatch`, safe only
because dispatch is synchronous. The real mechanism is a **transaction
annotation**, so permission travels with the transaction. Needs `Annotation`
added to the vendored bundle, alongside `@codemirror/search`.

**No CSS margins on anything the editor measures.** Margins fall outside the
box CodeMirror uses to build its height map; everything below a mismeasured
element drifts, and clicks and arrow keys land on the wrong line. Padding
always. This has bitten twice.

### 8.5 Version history — unchanged in shape

Read-only, no restore, one version per session, nothing pruned.

## 9. Images — unchanged

Notes only. The calendar has no attachments.

## 10. Reminders (deferred)

A reminder reads the derived index (§5.3), not a table of records. Solid Queue
already runs recurring jobs. A leading time in a line is an event's time.

## 11. Folder filing and ordering — unchanged

Notes only. Ordering in the calendar is the order of lines.

## 12. Task overflow — the reason for building this

When a task isn't done on the day it was scheduled, it moves to a future date.
Today that is cut and paste, which works and cost nothing to build.

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
   rewrite the marker in the same transaction. Half-built already.
2. A slash move command — `/move to 2 days`, `/move tomorrow`,
   `/move to 12 sep` — deletes at origin, creates the target date if needed,
   and inserts there. One transaction, one undo.

**Cut-and-paste can also be caught, with limits.** A `cut` handler can write a
private MIME type into the `DataTransfer` alongside `text/plain`, carrying each
line's origin date — which the plain text cannot, since the date heading isn't
part of the selection. On paste, compare a hash of the plain text against the
payload; if they disagree the content was edited in between, so drop the
metadata and paste plainly. Limits: it only works within one browser, never
across apps or to a native client; copy isn't a move; same-day pastes must be
excluded or reordering inflates counters; and a pasted block containing date
headings is a day being moved, not a task being deferred.

**Build the command first.** It is simpler and it answers whether the trace is
worth having at all. If it is, the clipboard version is how it catches the
habit you actually have.

**Rollover falls out of this.** Once markers exist, "what's still open from
past days" is a scan for undone lines dated before today.

**The count is the signal, not the trace.** A line wearing `×4` is not a task;
it is a project, or it is a lie. Design the rendering to make high counts
visible rather than tidy.

## 13. Technical approach

- Rails 8, SQLite, Solid Queue, Solid Cache. No Postgres, no Redis.
- Hotwire for the notes surfaces. The calendar is one Stimulus controller
  wrapping CodeMirror.
- **CodeMirror 6, vendored.** Bundled with esbuild on a laptop, committed to
  `vendor/javascript`, pinned in the importmap. No Node on the server.
- Plain CSS with custom properties; tokens port to an Android theme.
- Native `<dialog>` for the note modal.

## 14. Deployment — unchanged

MacBook Air on the tailnet, Capistrano over SSH, mise for the runtime, launchd
behind `tailscale serve`. Databases and blobs outside the release directory.
Nightly backup.

## 15. Native clients and the API

Native clients against a JSON API; reads HTML and writes JSON; both surfaces on
the same models.

- **The calendar's API is one document.** `GET /api/v1/years/2026` returns text,
  `PUT` replaces it. No per-entry endpoint, ever.
- **Conflict is a text merge, not a lost row.** Two clients editing different
  days of one year is now a document-level conflict where v13 had none.
  Mitigations in order: base-version check rejecting stale writes; three-way
  line merge, which text supports well; losing write becomes a `Version`.

### Android

- **The calendar panel is an ordinary Compose composable.** Lifting it out of
  the document made this free — it is a grid of dates with a click handler.
- **The editor is a `LazyColumn` with one `BasicTextField` per day.** Split the
  document on date lines to render, join on save. This suits the device: mobile
  capture is a few lines into one day, not a year-wide selection. It gives
  native IME, per-field undo, and lazy rendering of a year.
- Rejected: **a WebView** running the same bundle — one implementation, but
  mobile WebView text editing breaks on IME composition, autocorrect and
  selection handles, and cannot be fixed from inside. Rejected: **one field for
  the whole year** — no lazy rendering, and cross-day gestures nobody performs
  on a phone.
- Line-level styling is `OutputTransformation` on `BasicTextField`. What
  Compose cannot do is place composables *between* lines — which is exactly
  what the in-between strips are, and a second argument for dropping them
  (§20).

## 16. Import

- **The existing log file** is the first import and nearly free: it is already
  this format. Normalising date lines is the whole job.
- **Keep content** via Takeout. Labels become folders, notes become notes,
  nothing lands on the calendar.

## 17. Design principles

- Capture friction is the thing to optimise.
- Dark theme first.
- No confirmation dialogs except for destructive, unrecoverable actions.
- Legible at a glance from across a desk.
- **The document is the truth.** Nothing is stored that the writer didn't type.
  Anything else is derived and disposable.

## 18. Milestones

| # | Deliverable | Status |
|---|---|---|
| 1 | Rails skeleton, models, migrations, `user_id` scoping | ✅ built |
| 2 | Tiled board, card design, masonry, CSS tokens | ✅ built |
| 3 | Editor modal, autosave, create-on-keystroke | ✅ built |
| 4 | Sidebar tree, full-pane note, drag-to-file | ✅ built |
| 7 | Auth — OIDC client of `auth`, sessions, bearer API | ✅ built |
| 13 | Manual ordering — folders, sidebar notes, board cards | ✅ built |
| 5 | Images — upload, gallery, thumbnails | |
| 16 | API catch-up — notes and folders over /api/v1 | **next** |
| 6 | **Calendar — `YearDoc`, CodeMirror editor, syntax, panel** | prototyped |
| 8 | Search, archive, trash | |
| 14 | Version history — polymorphic, session capture, slider | |
| 19 | **Linking — `[[…]]`, resolution, backlinks** | |
| 20 | **Task overflow — push command, markers, rollover** | |
| 9 | Tailscale, mise on the server, Capistrano deploy | |
| 10 | Android — Compose client against /api/v1 | |
| 11 | Reminders | |
| 12 | Keep import | |
| 15 | macOS — SwiftUI client against /api/v1 | |

Milestone 6 is much smaller than in v13 — one table, one column, one editor —
and milestone 20 carries what was cut out of it. Every milestone from here
ships its JSON with its HTML.

## 19. Linking notes and days

`[[…]]` in the calendar refers to a note, so a day can point at the packing
list rather than restating it.

- **A link carries the note's UUID; the title is resolved and rendered at
  runtime.** Renaming never breaks a link and never rewrites text the writer
  typed. The cost is accepted: this is the one place the raw document is not
  fully readable on its own, and it buys correctness on duplicate titles and
  renames, both of which break immediately otherwise.
- Styled by decoration, like date lines and `done`.
- The `(user, date, target)` link table is part of the derived index (§5.3).
- Backlinks — "this note is mentioned on these days" — fall out of the index
  and should ship with it.
- A link does not date a note. §3's non-goal stands.
- **Autocomplete on `[[` is required, not optional.** Nobody types a UUID.
  This likely puts `@codemirror/autocomplete` in the bundle after all.

## 20. Open questions

1. **Do the in-between strips survive?** The pinned panel does everything they
   do, from a fixed position, without moving text. They are the last thing in
   the stream that isn't the writer's words, and the one piece that cannot
   cross to Compose. Decide by living with the panel for a week.
2. **What happens when a linked note is trashed or archived?** The link still
   resolves; pointing at something filed away needs a rendering answer.
3. **Do days get linked too** — `[[12 sep]]` from a note, or day to day? If so,
   the push command could write its trail as ordinary links.
4. **Where does a link open?** v13's rule is that the surface follows where you
   clicked. From the calendar, modal or full pane?
5. **Does note text get syntax too**, or is syntax calendar-only?
6. **Can a reminder time live in the line's own text?** If not, §5.3's index
   needs to be writable, which breaks "derived and disposable".
7. **Concurrent edits** to one year from two devices. Is a base-version check
   enough for one person with two machines?

Settled: links carry UUIDs with titles rendered at runtime; the `## ongoing`
and `## next cohort` lanes become an ordinary note rather than a second syntax;
a task crossing a year boundary is handled by hand (cut, switch year, paste);
Android is per-day native fields.

## 21. Known gaps in the prototype

Not design questions — things `stream-text.html` does not do yet.

- **Switching years does not save.** The dropdown replaces the document. The
  year-boundary workflow depends on fixing this.
- No persistence of any kind.
- `Mod-Enter` will append `done` to a date line if the cursor is on one.
- Dragging text onto a strip or the panel is untested.
- `@codemirror/search` is not bundled, so `Mod-f` and `Mod-d` do nothing. For a
  document that is a whole year this is the largest missing affordance.
- Slash command grammar is deliberately small: no suggestions, no fuzzy match,
  no natural-language date parser beyond the examples in §8.3.

## 22. Prior art

Pieces of this exist; the arrangement doesn't appear to.

- **NotePlan** is the closest product: markdown daily notes, tasks, calendar.
  Still page-per-day. Notably it **refuses to roll tasks over on purpose** —
  the manual work is the feature, forcing reconsideration instead of
  accumulation. Its move gestures are drag-to-a-day, a `>today` tag, or cut and
  paste. Same instinct as this document, reached independently.
- **Org-mode** already has the deferral trace. `org-log-reschedule` writes a
  timestamped entry into a LOGBOOK drawer whenever a scheduled date changes —
  in the document, as text, attached by position rather than id. Someone
  requested exactly this feature on the mailing list in 2009, in the same words
  (scheduling something, then lacking the capacity on the day). Read their edge
  cases before choosing a delimiter.
- **TaskPaper** is closest on the text model: one plain file, `@done` tags,
  highlighted in place, no records underneath.

What is absent everywhere: the continuous vertical year. The existing tools are
page-per-day or outlines; Obsidian plugins stitch daily notes into a scroll,
but that is stitching documents, not one document where a day is a span of
text.

That two of the three closest tools converged on **manual deferral** rather
than automatic rollover is worth taking seriously — it is evidence for §12's
"build the command, not the automation".
