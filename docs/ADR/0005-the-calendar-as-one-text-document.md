# 0005 — The calendar as one text document

**Status:** Accepted, 3 Sep 2026. Supersedes the calendar half of `docs/PRD.md`
v13 — §5 `DayEntry`/`DayLog`, §7.2, §8.3. Notes are untouched.

Prototyped in `calendar-prototyping/stream-text.html`.

## Context

The calendar was specified as records: a `DayEntry` row per line, a `DayLog` row
per day, an inline editor per field. The thing being replaced is a plain text
file, and both complaints about the daily-note apps had one cause — a day is a
separate document. You cannot see yesterday while writing today, and moving a
task to a future date means opening another page.

Prototyping showed the practice being modelled is text, and that the operations
that matter are text operations that records make expensive. A checkbox is a
PATCH, a reorder is a transaction, and cut-and-paste-a-week is not expressible
at all.

## Decision

**A year is one plain-text string.** One document, edited in one editor,
scrolling newest-first the way the existing log file already reads.

Dates are **syntax, not structure**. A line matching `12 sep` renders as a day
heading because it matches a pattern, not because a record exists behind it.
Delete those characters and the day is gone; type them anywhere and a day
appears. A day is the span between one matching line and the next. Nothing
stores it and nothing has an id.

Everything else on screen is derived from the text on every keystroke: headings,
weekend tints, strikethrough, and the grids of empty days between written ones.

The payoff is that the primary interaction is text editing, so it is already
complete and already correct. Undo, redo, selection across days, multi-line cut,
clipboard, find, mobile keyboards — none of these are features to build.

## Mechanism — CodeMirror 6

Chosen over two alternatives:

- **A `<textarea>` with a highlight layer behind it.** Zero dependencies and
  genuinely native undo, but the transparent textarea on top dictates the
  geometry, so every line must be exactly one line tall. No empty-day grids, no
  block widgets, nothing clickable. Colour and weight only.
- **`contenteditable` with a div per line.** Native undo survives only as long
  as you never mutate the DOM yourself, and decorating lines as you type is
  exactly that. Demos fine, then corrupts undo and normalises pasted content
  differently per browser.

CodeMirror is a plain-text document with its own history plus a decoration layer
that does line styling *and* block widgets of arbitrary height. Widget actions
dispatch as transactions, so a click that inserts a date lands in the same undo
history as typing it. One Cmd-Z, no special case. That single property is most
of the argument.

### The parse

```
DATE_RE = /^\s*(\d{1,2})\s+(jan|feb|…|dec)/i
```

Anchored at line start, deliberately lenient after the month, so `28 may 8.30pm`
and `24 apr night` both parse — the existing log's own habits keep working. It
also means a line stays a date while you are still typing past it.

The whole document is re-parsed on every transaction. A few hundred lines of
regex is sub-millisecond and removes any question of incremental invalidation.

### Three kinds of decoration

1. **Line decorations** — `date` (plus `wk` for weekends, `today`), `done`,
   `drop` for `not doing`/`fail`, `urgent`, `remind`. Pure styling from the
   line's own text.
2. **Block widgets** — the empty-day strips between two written dates. The only
   things on screen that are not text.
3. **A change filter** — locking date lines.

### Empty days are shortcuts, not records

Clicking a day in a strip **inserts the literal characters** `12 sep\n\n`. The
grid is not a thing that becomes real; it is a faster way of typing, and it
lands in undo history identically.

Because insertion is always at the boundary of the older neighbour, ordering
stays correct no matter which order the days are clicked. Nothing sorts
anything.

**The month calendar is not a widget.** It began as a block widget seated at
today's position and is now a fixed panel outside the editor entirely: no longer
measured by CodeMirror, so margins and shadows are free, it does not move the
text, and it ports to Compose as an ordinary composable. Clicking a day inserts
the date line at its correct position, found by scanning for the first date
older than it, so the panel works from anywhere.

### Locked date lines

A `changeFilter` rejects edits landing inside a date line, or edits that would
pull the line below up into it. Allowed on purpose: deleting a selected date
line whole (that is how a day is removed), and inserting at either end. A
refused edit flashes the line — silence reads as a broken editor.

The filter tests against the state *before* the change, which is what makes it
possible to type a date at all: a half-typed `12 se` is not a date yet, so it is
not protected yet.

### Slash commands are line-local text transforms

Typing `/` focuses a small input drawn at the cursor, with the slash inside the
input, so arguments can contain spaces. Enter applies, Escape leaves a literal
slash on editable lines, Backspace on a bare slash closes it. Every command ends
by writing ordinary calendar text; none store side data.

## Consequences

### A line has no identity

Cutting a task and pasting it under a future date is indistinguishable from
deleting one line and typing another. The deferral trace does not come for free.
It is recovered by putting the history **in the line's own text** —
`call the plumber ↩ 21 aug ×2` — written only when the app performs the move.
See `docs/PRD.md` §12.

### Structured queries get harder

"Every open action older than a week" is a parse over text, not a `WHERE`. At
one user and a few thousand lines a year that is nothing, but reminders read a
derived index rather than a table. The index is derived, never authoritative: if
index and text disagree, the text is right.

### Version history gets better

A whole year of text is a few tens of KB, so a version can store the entire
document. That is undo surviving a closed tab, with no merge question and no
per-record history to scope.

### Sync gets harder

Two clients editing one blob is a real conflict where two clients editing
different rows mostly is not. Text has better answers available than rows do
(three-way merge on lines), but ADR 0001 §6's "losing write becomes a `Version`"
is still the cheap fallback.

### Android cannot share the implementation

The editor becomes a `LazyColumn` with one `BasicTextField` per day: split the
document on date lines to render, join on save. This suits the device — mobile
capture is a few lines into one day, not a year-wide selection — and gives
native IME, per-field undo and lazy rendering.

Rejected: a **WebView** running the same bundle, because mobile WebView text
editing breaks on IME composition, autocorrect and selection handles, and cannot
be fixed from inside. Rejected: **one field for the whole year**, which loses
lazy rendering for cross-day gestures nobody performs on a phone.

What Compose cannot do is place composables *between* lines — which is exactly
what the empty-day strips are, and an argument for dropping them.

## Two constraints that cost a day each

**Never put a CSS margin on anything the editor measures.** CodeMirror builds a
height map from element boxes. Margins fall outside the box, so a margined line
or widget is measured shorter than it renders and every coordinate below it
drifts — clicks and arrow-key movement land a line or two off. Padding on the
element, or a wrapper with padding, always. This has bitten twice: `margin-top`
on date headings, and a margin on the empty-day strip. Both produced the same
symptom and neither looked like a measurement bug.

**Commands that write date lines need permission.** The change filter refuses
edits to date lines, but `insertDate`, the slash commands and the line-mover all
legitimately write them. The prototype raises a module-level flag around
`dispatch`, which works only because dispatch is synchronous. The correct
mechanism is a transaction **`Annotation`**, so the permission travels with the
transaction instead of sitting in module scope.

## Deployment

CodeMirror is bundled with esbuild on a laptop, committed to
`vendor/javascript`, and pinned in the importmap (~262KB minified). The build
step runs when CodeMirror is upgraded; the server only ever serves a file, so
the no-Node-on-the-server rule holds. `@codemirror/search`, `Annotation` and
`@codemirror/autocomplete` (for `[[` completion) belong in the next rebundle.

## Prior art

- **NotePlan** is the closest product — markdown daily notes, tasks, calendar —
  and still page-per-day. It **refuses to roll tasks over on purpose**: the
  manual work is the feature, forcing reconsideration instead of accumulation.
- **Org-mode** already has the deferral trace. `org-log-reschedule` writes a
  timestamped entry into a LOGBOOK drawer whenever a scheduled date changes, in
  the document, attached by position rather than id. Read its edge cases before
  choosing a delimiter.
- **TaskPaper** is closest on the text model: one plain file, `@done` tags,
  highlighted in place, no records underneath.

Absent everywhere: the continuous vertical year. Obsidian plugins stitch daily
notes into a scroll, but that is stitching documents, not one document where a
day is a span of text. That two of the three closest tools converged on manual
deferral rather than automatic rollover is evidence for building the move
command rather than the automation.
