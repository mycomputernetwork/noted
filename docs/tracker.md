# notbuk — tracker

Milestone status and where the work stands. This is the handoff target: it is
rewritten at the end of every session and read first at the start of one.
Milestone definitions and rationale live in the PRD; this is their live status.

_Last handoff: 14 Aug 2026, evening._

## Milestones

| # | Deliverable | Status |
|---|---|---|
| 1 | Rails skeleton, models, migrations, seeds, `user_id` scoping | ✅ built |
| 2 | Tiled board, card design, masonry, CSS tokens | ✅ built |
| 3 | Editor modal, autosave, create-on-keystroke | ✅ built |
| 4 | Sidebar tree — folders, note rows, full-pane note, drag-to-file | ✅ built |
| 5 | Images — upload, gallery, thumbnails | |
| 6 | Calendar day stream — events, actions, rollover, day log, inline editing | |
| 7 | Auth — email + password, sessions, rate limiting | |
| 8 | Search, archive, trash | |
| 9 | Tailscale, mise on the server, Capistrano deploy | |
| 10 | Android — Compose client against `/api/v1` | ▶ starting (alongside 16) |
| 11 | Reminders | |
| 12 | Keep import | |
| 13 | Manual ordering — drag to reorder folders and notes | |
| 14 | Version history — read-only slider over past bodies | |
| 15 | macOS — SwiftUI client against `/api/v1` | |
| 16 | API catch-up — notes/folders over `/api/v1`, shared scoping concern, autosave repointed | ▶ in progress |

**Working order: 16, then 10 alongside it.** The API catch-up comes first because
everything else now depends on it, including the Android client being built in
parallel. Remaining server order is set by what the client needs, not by what is
cheapest — which puts the calendar (6) ahead of images (5).

---

## Done
Milestones 1–4 are **committed** (`f1ceb14`, `7db9a34`, `54df03e`, `3ff5108`).
Milestone 4's suite passes on the Mac.

Uncommitted on top of `3ff5108`: the five fixes below, the caret icon, the API
ADR, and this file. `mise exec -- bin/rails test` before committing them — two
assertions were added to `sidebar_test.rb` (the folder name breaking out of its
frame, and `dragenter` on drop targets) and neither has been run.

Commits happen on the Mac; git can't be driven through the device bridge (see
`AGENTS.md`).

## Todos

## Bugs
- Drag to move notes in folders isn't working.

## Decided: native clients + a JSON API

**Native Compose and SwiftUI clients against a parallel `/api/v1`. The web app
stays Hotwire and is not an API client.** The full argument is in ADR 0001; the
short version is that the API sits beside the HTML surface rather than beneath it,
both stand on the same models and scopes, and a controller of either kind decides
what to render and nothing else. Anything a JSON caller can get wrong that an HTML
caller cannot is a rule written in the wrong place.

From milestone 5 on, every milestone ships its JSON with its HTML. Consequences
worth carrying:
- Notes and folders owe a one-time catch-up slice — built before the decision, and
  the smallest, best-understood part of the API.
- **Token issuance cannot ship before milestone 7.** There is nothing to issue a
  token against until sessions are real. Until then the API is as unauthenticated
  as the HTML app already is — a tailnet-only trust model, not a plan.
- Sync strategy is still open. "Last write wins" was written about two browsers,
  not a phone that has been offline for a day.

## Day one of milestone 16 — in this order

1. Extract `notes`/`folders`/`entries`/`logs` from `ApplicationController` into a
   `Scoped` concern. Do this before writing an endpoint, not after: a second
   controller hierarchy is exactly where "every query originates from
   `current_user`" quietly stops being true.
2. `Api::V1::BaseController` — `ActionController::API`, `Scoped`, `Authentication`,
   and one `rescue_from RecordNotFound` → 404.
3. `Api::V1::NotesController` and `Api::V1::FoldersController` with plain-Ruby
   serializers in `app/serializers`.
4. Repoint `autosave_controller.js`'s two URL values. Delete the JSON from
   `NotesController`, leaving it HTML only.
5. Isolation asserted against the API the way `test/models/isolation_test.rb`
   asserts it against the models — every path missing on another account's id,
   including the ones reached through `folder_id` in a body.

**What the Android client needs on day one, and what it should not wait for.**
Notes and folders are enough to build the board, the tree, filing and the editor —
most of the application. It should *not* wait for authentication: there is none on
either surface yet, `current_user` returns the seeded user, and the tailnet is the
only thing between the API and the world. Build against that, and expect a token to
be added rather than a login screen to appear.

**Write the wire format down as you go**, in ADR 0001 §3. It is a contract between
two people building at the same time, not notes to yourself. A field renamed after
the client has parsed it is not a refactor.

**One thing to decide before sign-in, not after** (ADR 0001 §2):
`ActionController::API` does not verify authenticity tokens. Correct for a native
client with a bearer token, unsafe for a browser with a session cookie — and the
browser is a caller. Authentication has to arrive as two paths into one `Session`
record. It decides where the filter sits, so it is worth knowing while the
endpoints are being written.

## Implementation logs

### What milestone 4 actually shipped

Shipped: the sidebar, the full pane, the folder board, filing by drag, and folder
create/rename/delete.

`Tree` is a plain object beside `Day` and `Year`: two queries — folders, then every
live note — grouped in Ruby, loaded in `ApplicationController` only for a GET that
renders HTML and is not a frame — without that guard the tree would be built and
thrown away on every autosave `PATCH`. Nothing is fetched per disclosure triangle.
Expansion state is `localStorage`, and what is stored is the **collapsed** set, so
a folder made later opens by default without migrating the stored value. A
collapsed folder opens anyway while the note inside it is the one being viewed,
without changing what is stored.

**The full pane is the third wrapper around `notes/_fields`, and it mounted
`autosave_controller.js` unchanged** — the point of building that controller
standalone. One URL serves both surfaces: `notes#show` renders the pane unless the
request carries a `Turbo-Frame: editor` header, in which case it renders the modal;
the frame header is the tell for where the click came from. The only edit the field
partial needed was to make its close button optional — leaving a pane is navigating
away, and autosave already flushes on `turbo:before-visit`. A Done button there
would have been a save button by another name.

`pane_controller.js` is the frame, four lines: there is no submit button anywhere,
but Enter in a text input still asks the form to submit. Everything else a frame
does — opening, focus, deciding what closing means — a page does on its own.

**Filing reuses the note's own endpoint.** A card dropped on a folder is a `PATCH`
to that note with a `folder_id`, so drag-to-file added no route and talks to the
same JSON the editor does. `filing_controller.js` is mounted on the shell rather
than the card or the rail, because the two ends of the drag are in different halves
of it and `dragstart` bubbles. Dropping on the Notes row unfiles, for the same
reason. The drop is optimistic — the card dims immediately and comes back with a
red flash on the row if the save fails.

The folder board is `notes/index` with one `where`, through a shared `BoardLoading`
concern. Sort controls rebuild the current URL with `url_for` rather than naming
`root_path`, so sorting a folder board stays on the folder. The composer on a
folder board carries that folder, so a note written there lands there. Folder
create, rename and delete happen in the tree and redirect to a full page (`_top`),
never into the row's frame — a rename changes every card's chip and every open
editor's select, none of which is inside that frame.

Navigation moved out of the header into the tree, the primary navigation from here
on. Below 52rem the rail is hidden outright rather than collapsed to icons: a tree
of note titles has nothing to show at 3rem.

`position` ships on `Note` unused — the tree orders by it, and every note's is null
until milestone 13 puts a hand on one.

Not in this milestone: manual drag ordering (13), images (5), archive and trash (8).

### What milestone 3 actually shipped

Shipped: the editor and the autosave controller behind it.

`autosave_controller.js` is mounted with a form, a create URL and — once the record
exists — an update URL, and knows nothing else. It debounces 800ms, saves
immediately on blur and on any deliberate change (folder, pin), chains every request
behind the one before so a slow response cannot land after a newer one, and flushes
on unload and on `turbo:before-visit` with `keepalive` so a navigation cannot
swallow the last keystroke. Milestone 4's full-pane note mounts this file unchanged;
if it needs an edit, it was built wrong.

`composer_controller.js` and `modal_controller.js` are frames and nothing else,
neither knowing anything about saving. The composer expands in place, treats a click
outside, Escape and Done as one act, and on close refreshes the board and marks the
card the note landed in — parked on the window as a one-shot `turbo:render` listener,
since the element that asked for the mark is gone by the time the board has
re-rendered. If nothing was typed, it collapses without touching the board.

`modal_controller.js` is a native `<dialog>`: `showModal` on connect, backdrop click
and Escape and Close all routed to the same `close` event. Both controllers sit on
the same element, because `input`, `change` and `focusout` bubble to the dialog while
`close` does not bubble at all — one element is the only place that sees every one of
them.

**The board refreshes on close, not on save.** Closing revisits the board's own URL,
which Turbo treats as a page refresh and — with `turbo-refresh-method: morph` in the
layout — patches rather than rebuilds. Replacing the card in place would leave the
board sorted wrongly, since editing a note is exactly what moves it to the front
under "last edited". The refresh is triggered by `autosave:finalized`, not the close
event, so it cannot render the note as it was before the last save landed.

**Endpoints answer JSON, not Turbo Streams.** They are called by a fetch, never a
form submission, and what the client needs back is where to send the next save. A
stream response would make the save path depend on the surface that issued it — the
coupling the shared controller exists to prevent.

**`DELETE /notes/:id` is discard, not delete.** It refuses anything not
`Note#empty?`, so the one case it serves — a note created on the first keystroke and
emptied out before the editor closed — is served, and an autosave bug can cost a
keystroke but never a note. Getting rid of a note the user still has content in is
milestone 8's trash, through `deleted_at`.

Cards are `<article>`s wrapping a link that covers them, rather than links: milestone
4 makes the card a drag source, and a draggable link drags its href.

The fields live in one partial (`notes/_fields`) that knows nothing about the surface
it is on; the dialog and the composer are wrappers around it. Milestone 4's full pane
is a third wrapper — the cheapest possible shared save path, and the thing that stops
the pane becoming a second editor.

Not in this milestone: images (5), the full-pane note (4), archive and trash (8).

### What milestone 2 actually shipped

The tiled board at `root`: design tokens, note cards, and masonry as a grid of 1px
rows with a computed span per card. Sort (edited or created, either direction) is URL
state rather than session state. The type scale is sized per role — 17px card body as
the base, 21px titles, 14px chrome, 12.5px metadata, 11px section labels — rather than
one size multiplied, so metadata does not grow in step with the text being read. The
milestone 1 smoke-test page and its controller are gone. Notes are read-only until
milestone 3.

The sidebar is **not** in milestone 2. The board shell reserves no space for it;
milestone 4 introduces the two-column shell.

### What milestone 1 actually shipped

Schema and models for `User`, `Session`, `Folder`, `Note`, `DayEntry`, `DayLog`, plus
the `Day`/`Year` composers and a `PurgeTrashedNotesJob` wired into Solid Queue's
recurring schedule. Seeds include a **second account whose content is labelled
`LEAK CANARY`** — if one ever appears in the interface, a query has escaped
`current_user`. `test/models/isolation_test.rb` asserts the property directly.

Runtime as built: Ruby 3.4.10, Rails 8.1.3.1, Bundler 2.6.9, 68 tests.

## Open questions

1. **Mail delivery.** Deferred. Password reset is stubbed until this exists. Needed
   before milestone 9 if anyone other than the owner is expected to recover an account
   unaided.
2. **Tailnet configuration.** Deferred, not blocking. MagicDNS and HTTPS certs are
   wanted for TLS before milestone 9.
3. **Storage visibility surface.** Is a plain settings figure enough, or is a small
   owner-facing view across all users wanted?
4. **Completed actions on a past day.** Once a day is in the past, should its completed
   actions stay visible in the stream or collapse into a count? Only matters once there
   is enough history to scroll through.
5. **Search across types.** Results are grouped by type. Whether a day-entry hit links
   into the calendar at that day or opens something modal is undecided until milestone 8.
6. **Offline sync.** Two questions, neither forced before milestone 10, both with schema
   consequences: how a record created offline gets an id (a client-generated UUID column
   on every table, or a local outbox that rewrites ids on acknowledgement), and whether a
   losing write becomes a `Version` rather than nothing. ADR 0001 §6 argues for the
   second.
7. ~~**Solid Queue / Cache / Cable schemas.**~~ **Closed at milestone 4.**
   `db/cache_schema.rb`, `db/queue_schema.rb` and `db/cable_schema.rb` were written by
   `db:migrate` preparing all four databases, so production config now points at schemas
   that exist. Milestone 9 no longer has to generate them.
