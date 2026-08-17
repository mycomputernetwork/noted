# noted — tracker

Milestone status and where the work stands. This is the handoff target: it is
rewritten at the end of every session and read first at the start of one.
Milestone definitions and rationale live in the PRD; this is their live status.

_Last handoff: 17 Aug 2026._

## This session (milestone 10 — real-time sync)

**Real-time push added to both surfaces.** Server broadcasts a nudge (type + id) over Action Cable on every Note/Folder `after_commit` via `SyncBroadcast` concern. `SyncChannel` streams per-user.

**Web:** `sync_controller.js` (Stimulus) subscribes to `SyncChannel`; on nudge, debounces 300ms then morphs the page via `Turbo.visit(location, { action: "replace" })`. `@rails/actioncable` pinned in importmap. Controller attached to the shell div so it lives across navigations.

**Android:** `CableClient` speaks the Action Cable WebSocket protocol (subscribe JSON over OkHttp WebSocket). Emits nudges as a `Flow<Unit>`. `BoardViewModel` collects nudges and calls `sync()` (push-then-pull via existing `SyncEngine`). WebSocket connects in `viewModelScope` so it tears down when the ViewModel clears (app backgrounded / activity destroyed).

**Auth stub:** both Connection and CableClient use the same single-seed-user stub as the rest of the app. Milestone 7 replaces this with token-based identification.

## Previous session (milestone 10 — sync slice + Android foundation)

**Server sync slice built.** `GET /api/v1/changes?cursor=` returns notes + folders
changed after an opaque cursor (tombstones included; no cursor = full snapshot) and
a new `cursor` (server time, treated opaque by clients). Folder delete is now a
soft-delete (`deleted_at`) that unfiles its notes, on both API and web; `deleted_at`
added to `folders` with `updated_at` indexes on notes/folders. `Folder.kept` scope;
all web callers (`Tree`, notes/folders controllers) go through it. Rswag `Changes`
schema + spec added, swagger regenerated. Full suite: 160 examples, 0 failures.

**Android client foundation built and building** (`./gradlew assembleDebug` green).
Stack: Retrofit + kotlinx.serialization, Room (offline source of truth), DataStore
(sync cursor), Compose + navigation. `SyncEngine` does push-then-pull, last-write-wins:
dirty/pendingCreate/pendingDelete flags per row, client-generated UUIDs so offline
creates need no id rewrite; pull skips locally-dirty rows. UI per the mobile design:
staggered-grid board, folders as filter pills on top ("All" default, no sidebar),
bottom-right FAB for new note, editor with 800ms debounced autosave. Base URL
`http://10.0.2.2:3000` (emulator→host). No auth yet (tailnet trust).

**Build gotchas recorded:** AGP 9 built-in Kotlin needs
`android.disallowKotlinSourceSets=false` for KSP; Room must be 2.7.1 (2.6.1 fails
KSP2 with "unexpected jvm signature V").

**Next:** run against the emulator end-to-end; images/calendar/auth are later
milestones. Consider periodic/foreground sync trigger (WorkManager) — currently
sync fires on launch, on folder create, and on editor close.

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
| 10 | Android — Compose client against `/api/v1` | ▶ in progress |
| 11 | Reminders | |
| 12 | Keep import | |
| 13 | Manual ordering — drag to reorder folders and notes | |
| 14 | Version history — read-only slider over past bodies | |
| 15 | macOS — SwiftUI client against `/api/v1` | |
| 16 | API catch-up — notes/folders over `/api/v1`, shared scoping concern, autosave repointed | ✅ built |

**Working order: 16, then 10 alongside it.** The API catch-up comes first because
everything else now depends on it, including the Android client being built in
parallel. Remaining server order is set by what the client needs, not by what is
cheapest — which puts the calendar (6) ahead of images (5).

---

## Done
Milestone 16 now has `/api/v1/notes` and `/api/v1/folders`, a shared `Scoped` concern, `Api::V1::BaseController`, plain Ruby serializers, browser note autosave pointed at the API, and generated Rswag docs at `swagger/v1/swagger.yaml` served through `/api-docs`. The docs now carry reusable `Folder`/`Note`/`Errors` component schemas with per-field descriptions, request-body field descriptions, and per-endpoint descriptions; responses are validated against those schemas. The whole suite is now RSpec (Minitest removed); `bundle exec rspec` passes: 158 examples.

Project rename to `noted` is applied across Rails names, docs, env var names, session/local-storage keys, seed/test emails, and the Android package/app/theme names.

Milestones 1–4 are **committed** (`f1ceb14`, `7db9a34`, `54df03e`, `3ff5108`).
Milestone 4's suite passes on the Mac.

Uncommitted on top of `3ff5108`: the five fixes below, the caret icon, the API
ADR, the Minitest→RSpec conversion, and this file. `mise exec -- bundle exec rspec`
before committing.

**Uncommitted, previous session — the all-UUID schema change (ADR 0002).** Every
table now has a string (UUID) primary key; folder-name uniqueness and the 30-day
trash purge are gone. The current schema has been exercised by both suites in
this session.

Commits happen on the Mac; git can't be driven through the device bridge (see
`AGENTS.md`).

## Todos
- Milestone 10 (Android/Compose) is unblocked: notes + folders over `/api/v1` are enough for the board, tree, filing, and editor. Build against the tailnet trust model; expect a bearer token to be added at milestone 7, not a login screen.

## Done this session (milestone 16 closeout)
The test-framework move is finished: the whole model/HTML suite is now RSpec. The 14 Minitest files under `test/models/` and `test/controllers/` were converted to `spec/models/*_spec.rb` and `spec/requests/*_spec.rb` and deleted, along with `test/test_helper.rb`. Fixtures stay in `test/fixtures/` (referenced by `spec/rails_helper.rb`). Shared helpers (`owner`/`other`, `board_titles`, `dom_id`) live in `spec/support/helpers.rb`; `assert_select`/`assert_response` come from rspec-rails request example groups unchanged, `assert_no_match` (Minitest-only) became `expect(...).not_to match(...)`. `bundle exec rspec` passes: 158 examples, 0 failures. The `Rswag::Ui` deprecation is resolved by renaming `swagger_endpoint` to `openapi_endpoint` in `config/initializers/rswag_ui.rb` (the method already exists in rswag-ui 2.17). Milestone 16 is done.

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
- Sync strategy is decided (ADR 0002): last write wins, a stale write is
  accepted, and version history is not overloaded to preserve overwrites. Every
  table has a client-generated UUID primary key, so a record made offline needs
  no id rewrite. Version history (milestone 14) is time-bucketed on save — a new
  version when the last is more than ten minutes old, via a backend callback —
  and is independent of sync.

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
6. ~~**Offline sync.**~~ **Decided (ADR 0002).** Last write wins, a stale write is
   accepted, and a losing write is not preserved as a `Version`. Records created
   offline carry a client-generated UUID — every table now has a UUID primary key,
   so there is no outbox rewriting ids. Still to build with milestone 10: the
   `GET /api/v1/changes?since=` endpoint, `deleted_at` tombstones on `folders`
   and `day_logs`, and an `updated_at` index per synced table (ADR 0001 §5).
7. ~~**Solid Queue / Cache / Cable schemas.**~~ **Closed at milestone 4.**
   `db/cache_schema.rb`, `db/queue_schema.rb` and `db/cable_schema.rb` were written by
   `db:migrate` preparing all four databases, so production config now points at schemas
   that exist. Milestone 9 no longer has to generate them.
