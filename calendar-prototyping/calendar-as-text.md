# The calendar as one text document

**Status:** direction, prototyped in `stream-text.html`
**Date:** 3 Sep 2026 (revised)

Supersedes the calendar half of the noted PRD (§5 `DayEntry`/`DayLog`, §7.2, §8.3).
Notes are untouched by this.

---

## 1. The premise

A year is **one plain-text string**. Not a list of days, not a row per entry.
One document, edited in one editor, scrolling newest-first the way the existing
log file already reads.

Dates are **syntax, not structure**. A line matching `12 sep` renders as a day
heading because it matches a pattern, not because a record exists behind it.
Delete those characters and the day is gone. Type them anywhere and a day
appears.

Everything else on screen is derived from the text on every keystroke:
headings, weekend tints, strikethrough on completed lines, and the grids of
empty days between written ones.

## 2. Why

The thing being replaced is a plain text file, and the two complaints about the
daily-note apps were both about the same cause: a day is a separate document.
You can't see yesterday while writing today, and moving a task to a future date
means opening another page.

One document answers both. Previous days are literally on screen above and
below. Moving a task forward is cut and paste, which is a gesture that already
exists and can't fail.

The wider payoff is that **the primary interaction is text editing**, so it is
already complete and already correct. Undo, redo, selection across days,
multi-line cut, clipboard, find, mobile keyboards — none of these are features
to build. They come from using a real text editor instead of a form.

Compare the record-per-entry version: a checkbox is a PATCH, a reorder is a
transaction, and cut-and-paste-a-week is not expressible at all.

## 3. What it costs

**A line has no identity.** When you cut a task and paste it under a future
date, the app cannot distinguish that from deleting one line and typing
another.

So the deferral trace — `→ 8 sep` on the origin day, `↩ 28 aug` on the target,
a count of how many times something has slid — does not come for free. Getting
it back needs one of:

- a **command** that performs the move (`Mod-↓` to push a line to a date), so
  the app is the one doing it and can write the trail;
- an **invisible marker** on the line, which puts syntax in the document for
  the app's benefit rather than the writer's.

Half of the first now exists: `Alt-↑`/`Alt-↓` move a line and will happily
cross a date heading, which *is* the gesture. Because the app performs it, it
already knows the origin and the target — it simply doesn't write anything
down. Worth living in the plain version for a while to find out whether the
trace is wanted at all.

**Structured queries get harder.** "Every open action older than a week" is a
parse over text, not a `WHERE`. At one user and a few thousand lines a year
that is nothing, but it does mean reminders (PRD §10) read a derived index
rather than a table.

## 4. Mechanism

CodeMirror 6. Chosen over the two alternatives:

- **A `<textarea>` with a highlight layer behind it.** Zero dependencies and
  genuinely native undo, but the transparent textarea on top dictates the
  geometry, so every line must be exactly one line tall. No empty-day grids, no
  block widgets, nothing clickable. Colour and weight only.
- **`contenteditable` with a div per line.** Looks like the obvious answer.
  Native undo survives only as long as you never mutate the DOM yourself, and
  decorating lines as you type is exactly that. Demos fine, then corrupts undo
  and normalises pasted content differently per browser.

CodeMirror exists for precisely this shape: a plain-text document with its own
history, plus a decoration layer that does line styling *and* block widgets of
arbitrary height. Widget actions dispatch as transactions, so a click that
inserts a date lands in the same undo history as typing it. One Cmd-Z, no
special case. That single property is most of the argument.

### The parse

```
DATE_RE = /^\s*(\d{1,2})\s+(jan|feb|…|dec)/i
```

Anchored at line start, deliberately lenient after the month, so `28 may 8.30pm`
and `24 apr night` both parse — the existing log's own habits keep working. It
also means a line stays a date while you are still typing past it.

A **day is not an object.** It is the span between one matching line and the
next. Nothing stores it and nothing has an id. Tab-to-next-date is literally
"scan forward for a line matching the pattern".

The whole document is re-parsed on every transaction. ~400 lines of regex is
sub-millisecond and removes any question of incremental invalidation.

### Three kinds of decoration

1. **Line decorations** — `date` (plus `wk` for weekends, `today`), `done` for
   lines ending in `done`, `drop` for `not doing` / `fail`. Pure styling from
   the line's own text.
2. **Block widgets** — the empty-day grids, placed between two written dates,
   plus one above the newest date for the future. These are the only things on
   screen that are not text.
3. **A change filter** — see below.

### Empty days are shortcuts, not records

A grid of missing days sits between each pair of written dates, laid out under
Mon–Sun columns so the days fall in their true weekday positions, Sundays in
red. Clicking a day **inserts the literal characters** `12 sep\n\n` at that
position. The grid is not a thing that becomes real; it is a faster way of
typing.

Because insertion is always at the boundary of the older neighbour, ordering
stays correct no matter which order you click. Insert 20 sep, and 12 sep now
appears in the gap below it and inserts there instead. Nothing sorts anything.

**The month calendar is not a widget.** It began as a block widget seated at
today's position and is now a fixed panel outside the editor entirely. That
turned out to be the better place for it: it is no longer measured by
CodeMirror, so margins and shadows are free, it does not move the text, and it
ports to Compose as an ordinary composable. Clicking a day inserts the date
line at its correct position in the document, found by scanning for the first
date older than it — so the panel works from anywhere and does not need to know
where it sits.

This leaves the in-between strips as the only widgets, and raises the question
of whether they still earn their place.

### Locked date lines

A `changeFilter` rejects edits landing inside a date line, or edits that would
pull the line below up into it. Allowed on purpose: deleting a selected date
line whole (that's how a day is removed), and inserting at either end.

The filter tests against the state *before* the change, which is what makes it
possible to type a date at all — a half-typed `12 se` isn't a date yet, so it
isn't protected yet.

### Never put a margin on anything the editor measures

CodeMirror builds a height map from element boxes. Margins fall outside the
box, so a margined line or widget is measured shorter than it renders and every
coordinate below it drifts — clicks and arrow-key movement land a line or two
off. Padding on the element, or a wrapper with padding, always.

This has bitten twice: `margin-top` on date headings, and a margin on the
empty-day strip. Both produced the same symptom and neither looked like a
measurement bug.

### Commands that write date lines need permission

The change filter refuses edits to date lines, but `insertDate`, slash commands
and the line-mover all legitimately write them. The prototype raises a
module-level flag around `dispatch`, which works only because dispatch is
synchronous. The correct mechanism is a **transaction annotation**, so the
permission travels with the transaction instead of sitting in module scope.

### Slash commands are line-local text transforms

Typing `/` immediately focuses a small input drawn at that cursor position,
with the slash inside the input. The command's arguments live there, so spaces
belong to the command rather than to the document. It can open on entries,
blank lines, and date headings. Enter applies the command; Escape leaves a
literal slash only on editable lines; Backspace on a bare slash closes it.

The prototype commands are deliberately plain: `done`, `not doing`, `fail`,
`urgent`, `schedule at 9pm`, `schedule call sam at 9pm on 12 sep`,
`move to 2 days`, `move to 12 sep`, and `remind-over-days`. They all end by
writing ordinary calendar text. `move` creates the target date line if needed
and writes the deferral trace into the line itself. A schedule command with an
`on`/`to` date creates the entry there from anywhere in the document. Trace
markers render smaller and dimmer than the task text, and inline dates render
as jump links to that day.

### Interface state stays out of the document

Which month is open in the future strip is a plain variable, not text. Same
rule as the PRD's sidebar expansion state (§7.6): interface state is not user
data.

## 5. What this does to the data model

`DayEntry` and `DayLog` stop being the source of truth. In their place:

| | |
|---|---|
| **Stored** | one text blob per user per year |
| **Derived** | parsed entries, as an index for search and reminders |

This also settles something the PRD got wrong. It separated entries (planned)
from the day log (what happened) as different objects on the grounds that they
are written at different times with different rhythms. The actual log never
made that distinction — it is one list of lines per day, some of which get
`done` appended. One text block per day is what the practice already is.

**Version history gets better, not worse.** A whole year of text is a few tens
of KB, so the §8.5 snapshot-per-editing-session rule can store the entire
document each time. That's undo that survives closing the tab, with no merge
question and no per-record history to scope.

**Sync gets harder in an interesting way.** Two clients editing one blob is a
real conflict, where two clients editing different rows mostly isn't. Text has
better answers available than rows do (three-way merge on lines), but the
"losing write becomes a Version" plan from ADR 0001 §6 is still the cheap
fallback.

## 6. Deployment note

The prototype has CodeMirror bundled inline (esbuild, ~262KB minified) because
the ESM CDN wasn't reachable. That is also the right shape for the real app:
vendor the bundle into `vendor/javascript`, pin it in the importmap. The build
step runs on a laptop when CodeMirror is upgraded; the server only ever serves
a file, so PRD §13's no-Node-on-the-server rule holds.

## 7. Open

- Tab currently moves **down** the document, which is backwards in time. Flip?
- No persistence. The year dropdown wipes the document rather than saving it.
- `@codemirror/search`, `Annotation`, and probably `@codemirror/autocomplete`
  (for `[[` completion) all belong in the next rebundle.
- Slash command grammar has no suggestions, fuzzy matching or real date parser.
- Whether the in-between strips survive now that the panel exists.

Settled since first draft: links carry a note's UUID with the title rendered at
runtime; the `## ongoing` / `## next cohort` lanes become an ordinary note; a
task crossing a year boundary is handled by hand; the deferral trace goes in
the line's own text (see PRD §12); Android is per-day native text fields, not a
WebView.
