# notbuk — where things stand (14 Aug 2026, evening)

## Done
Milestones 1–4 are **committed** (`f1ceb14`, `7db9a34`, `54df03e`, `3ff5108`).
Milestone 4's suite passes on the Mac.

Uncommitted on top of `3ff5108`: the five fixes below, the caret icon, the API
decision records and plan, and this file. `mise exec -- bin/rails test` before
committing them — two assertions were added to `sidebar_test.rb` (the folder
name breaking out of its frame, and `dragenter` on drop targets) and neither
has been run.

Git still can't be driven through the Cowork device bridge (it leaves
`.git/*.lock` files it can't remove), so commits happen on the Mac. To have
Claude commit directly, start the task from the desktop app's "Run this task"
picker → run on your computer.

## What to click first
This list is the regression suite. There are no frontend tests and there are
not going to be any (decided), so it is worth keeping current as surfaces are
added — it is the only thing that exercises the five Stimulus controllers.

1. **The tree.** Folders collapse and survive a reload. Open a note whose
   folder is collapsed — the folder should open anyway and close again when
   you leave. Then close an editor and check the collapsed ones *stayed*
   collapsed: that was the morph bug.
2. **A sidebar note row → full pane.** Type, then click Back. The edit must be
   on the board. This is the milestone's actual test: the pane mounts
   `autosave_controller.js` unchanged.
3. **A card → still the modal.** Same note, same URL, different surface.
4. **Drag a card onto a folder.** Then drag one onto "Notes" to unfile it.
   Worth doing in Firefox specifically — that is where it was broken, and
   Firefox is the browser that needs a drag accepted on entry, not only on
   hover. Dragging to *reorder* is milestone 13 and is not built.
5. **Click a folder name** — it should load a board, not say "content
   missing".
6. **Type a folder name at the foot of the list**, rename it (✎ on hover, and
   reachable by Tab), delete it — its notes must survive as unfiled.

## Milestone 4 as built
- `Tree` (`app/models/tree.rb`) — two queries, grouped in Ruby, loaded in
  `ApplicationController` only for GET + HTML + not-a-frame. The guard
  matters: without it the tree would be built and thrown away on every
  autosave `PATCH`.
- **One URL, two surfaces.** `notes#show` renders the pane unless the request
  carries `Turbo-Frame: editor`, in which case it renders the modal as before.
  The frame header is already a record of where the click came from. PRD §7.7
  amended to say so.
- **The field partial needed one edit**: the close button is now optional,
  because the pane has nothing to close. Everything else in `notes/_fields` is
  untouched and `autosave_controller.js` is untouched, which is what §18 asked
  for.
- **Filing is a `PATCH` to the note**, not a folder operation — no new route.
  `filing_controller.js` sits on the shell because `dragstart` bubbles and the
  two ends of the drag are in opposite halves of it. Optimistic: the card dims
  on drop, and comes back with a red flash on the row if the save fails.
- Expansion state stores the **collapsed** set, so folders made later default
  to open without migrating what is stored.
- Folder CRUD lives in the tree. Create/rename/delete all redirect to a full
  page (`_top`), never into the row's frame — a rename moves the folder,
  changes every card's chip and every open editor's select, and none of that
  is inside that frame.
- The header nav is gone; the tree is the navigation now (§6). Below 52rem the
  rail is hidden outright.
- `notes.position` ships unused, per §18. The tree orders by it; nothing
  writes it until milestone 13.

## Watch for on first run
- **The autosave retry is still unexercised** — it was unexercised at the end
  of milestone 3 too. Backoff 1s → 30s, reset on success, immediate retry on
  `online`. To see it: open a note, stop the server, type, watch the status
  line count down, start the server again.
- **A flash of open tree on load.** The server renders every folder expanded
  and `tree_controller` collapses on connect. If it blinks, the fix is to
  render the collapsed state server-side, which means it stops being purely
  interface state — check it actually blinks before paying that.
- `dragleave` fires when the pointer crosses a child of a drop row, so the
  highlight may flicker. If it does, the fix is an enter/leave counter.
- The pane never runs `discardIfEmpty` — nothing can create an empty note
  there, since the note already exists. Emptying one out in the pane leaves an
  empty note, which is correct: discarding is for notes born on a keystroke.
- The tree ships every note's full `body` on every page load, because an
  untitled row is labelled by its first line. Fine at §4's scale and not worth
  touching yet; the cheap lever when it stops being fine is `substr(body, 1,
  120)` in `Note.for_tree`'s select, and it is worth knowing that before the
  page is slow rather than after.
- `docs/previews/*.html` predate milestone 3 and 4 both. The sidebar prototype
  is where this CSS came from and is now behind the real thing.

## Still open from before
- `User#time_zone` — nullable column now is free, and the calendar (6) leans
  on "today".
- Keyboard capture (`n` opens the composer). §17 says the fastest capture is a
  keystroke.
- The web app on a phone over Tailscale — the rail is hidden below 52rem,
  which makes this more pressing than it was.
- CSP / security headers, and verifying a backup *restores* → both fold into
  milestone 9.

## Fixed after the first run-through
Four bugs found by clicking, one by reading:

- **Clicking a folder said "content missing."** The folder's name link lived
  inside the row's turbo frame, so Turbo tried to load a whole board into a
  24px row and — correctly — refused. The name now carries `_top`; only the
  rename link belongs to that frame.
- **Filing didn't work in Firefox.** A drop target has to accept the drag on
  `dragenter` as well as `dragover` there, or `drop` never fires.
  `dragleave` now also ignores leaving into its own children, which was
  flashing the highlight across a two-word row.
- **Collapsed folders sprang open after closing an editor.** Closing morphs
  the page, morphing syncs attributes against the server's markup, and
  `hidden` on the tree's children is set by the client — so it was stripped,
  and the rail element surviving the morph meant `connect` never ran to put
  it back. `tree_controller` re-applies on `turbo:morph` and `turbo:render`.
  Worth remembering as a class of bug, not a one-off: any client-only state
  inside a morph target has this problem.
- **Rename was keyboard-unreachable.** It was hidden with `display: none`,
  and a `display: none` element cannot take focus, so the `:focus-within`
  rule that was supposed to reveal it could never fire. Hidden by opacity now,
  and it keeps its slot so the row no longer reflows under the pointer.
- **`config.x.autosave_debounce_ms` was read by nothing.** Deleted. The
  window is declared once, in the controller that owns the timer.

The caret is now a drawn SVG rotated by CSS off `aria-expanded`, like the
thumbtack in `notes/_pin_icon` — one drawing rather than two glyphs, and one
place where open/closed is written.

## Decided today: §15, the API

**Native Compose and SwiftUI clients against a parallel `/api/v1`. The web app
stays Hotwire and is not an API client.** PRD §15 rewritten with the full
argument; the short version is that the API sits beside the HTML surface
rather than beneath it, both stand on the same models and scopes, and a
controller of either kind decides what to render and nothing else. Anything a
JSON caller can get wrong that an HTML caller cannot is a rule written in the
wrong place.

From milestone 5 on, every milestone ships its JSON with its HTML. Two
consequences worth carrying:
- Notes and folders owe a one-time catch-up slice — they were built before the
  decision. Smallest and best-understood part of the API.
- **Token issuance cannot ship "alongside" anything before milestone 7.**
  There is nothing to issue a token against until sessions are real. Until
  then the API is exactly as unauthenticated as the HTML app already is, which
  is a tailnet-only trust model, not a plan.
- Sync strategy is still open. "Last write wins" (§3) was written about two
  browsers, not about a phone that has been offline for a day.

## Asked and answered earlier
**Native clients (SwiftUI/macOS + Compose/Android).** Rough sizing, not a
decision: the server is close — milestone 3's endpoints already answer JSON,
so `/api/v1` is a namespace, a token endpoint and serializers for four flat
plain-text models, about one milestone. Each client is 4–8 weeks solo for
parity at today's scope, doubling if offline is real (Room / SwiftData +
sync) rather than a cache. Free on macOS: the tree
(`NavigationSplitView` + `OutlineGroup`) and filing (`.draggable` /
`.dropDestination`); masonry needs a custom `Layout`. Free on Android:
masonry (`LazyVerticalStaggeredGrid`); the tree doesn't. The autosave
controller is a real rewrite on both and the one worth porting carefully,
being the only part that can lose data. PRD §15's Turbo Native shell is days
rather than weeks and gives exact visual parity for free; offline is the only
thing a native client actually buys. **§15's decision — API or not — wants
making before the controllers are finalised, and everything so far leans
API.**

## Next — and it changes shape tomorrow

**Milestone 16, the API catch-up, goes first. The Android client starts
alongside it.** That second fact is the one that reorganises everything else:
from tomorrow there is a consumer waiting on the server, so the API stops
being a thing to add later and becomes the interface between two people
working at once.

**Day one of 16** — small, and worth doing in this order:

1. Extract `notes`/`folders`/`entries`/`logs` from `ApplicationController`
   into a `Scoped` concern. Do this before writing an endpoint, not after: a
   second controller hierarchy is exactly where "every query originates from
   `current_user`" quietly stops being true.
2. `Api::V1::BaseController` — `ActionController::API`, `Scoped`,
   `Authentication`, and one `rescue_from RecordNotFound` → 404.
3. `Api::V1::NotesController` and `Api::V1::FoldersController` with plain-Ruby
   serializers in `app/serializers`.
4. Repoint `autosave_controller.js`'s two URL values. Delete the JSON from
   `NotesController`, which leaves it rendering HTML only.
5. Isolation asserted against the API the way `test/models/isolation_test.rb`
   asserts it against the models — every path missing on another account's id,
   including the ones reached through `folder_id` in a body.

**What the Android client needs on day one, and what it should not wait for.**
Notes and folders are enough to build the board, the tree, filing and the
editor — that is most of the application. It should *not* wait for
authentication: there is none on either surface yet, `current_user` returns the
seeded user, and the tailnet is the only thing standing between the API and
the world. Build against that, and expect a token to be added rather than a
login screen to appear.

**Write the wire format down as you go**, in `docs/api-plan.md` §3. It is now
a contract between two people building at the same time, not notes to
yourself. A field renamed after the client has parsed it is not a refactor.

**Then the calendar (6) rather than images (5).** With a client in flight the
order of server work is set by what the client needs, not by what is cheapest.
The calendar is half the product and its data is flat plain text a new client
can consume immediately; images mean direct upload, expiring blob URLs and a
local byte cache, which is the hardest thing to hand a client that barely
exists. Recorded in PRD §18 — change it if the phone turns out to want photos
before it wants days.

**One thing to decide before sign-in, not after** (PRD §15, `api-plan` §2):
`ActionController::API` does not verify authenticity tokens. Correct for a
native client with a bearer token, unsafe for a browser with a session cookie
— and the browser is a caller. Authentication has to arrive as two paths into
one `Session` record. It decides where the filter sits, so it is worth knowing
while the endpoints are being written.

## Housekeeping
`_to_delete/` (gitignored) holds old smoke-test files, stale git locks and a
scratch tarball or two — safe to delete.
