# noted — tracker

Milestone status and where the work stands. This is the handoff target: it is
rewritten at the end of every session and read first at the start of one.
Milestone definitions and rationale live in the PRD; this is their live status.

_Last handoff: 19 Aug 2026._

## Where the work stands

**Milestone 7 (auth) is built and exercised.** noted is a client of `auth`, the
fleet's OIDC provider at `~/work/mcn-auth` (ADR 0003). Passwords are gone from
the design: `users.auth_sub` is the identity of record, `sessions.sid` is what a
back-channel logout deletes, and `sessions.issuer` records which provider minted
a session so a stub one cannot survive a switch to the real one.

- **Web:** `/sign_in` runs Authorization Code + PKCE through
  `omniauth_openid_connect`; the callback verifies the ID token, finds or creates
  the account by `sub`, and mints noted's own cookie session. An account menu in
  the header is the way out.
- **API:** `/api/v1` takes `Authorization: Bearer`, verified by `TokenVerifier`
  against auth's JWKS (cached 12h, refetched on an unknown `kid`), and also
  accepts noted's own cookie because the web editor saves through those same
  endpoints. 401 is documented on every operation; swagger regenerated.
- **Logout:** `POST /auth/backchannel_logout` verifies a logout token and deletes
  the session with that `sid`.
- **Development needs no auth service.** `mise run server` uses a stub issuer:
  identities from `config/dev_users.yml`, tokens signed with the checked-in
  keypair in `config/auth_stub/` and verified through the same code path as
  production. `mise run server-oidc` swaps in the real provider on `:3001`. The
  initializer refuses to boot `stub` outside development and test.

**Walked live on 19 Aug:** sign-in through the real provider, a Google identity
arriving with a UUID subject, and a back-channel logout delivered from auth and
consumed here — auth recorded `delivered`, noted's federated session vanished,
its stub sessions were left alone.

**Two bugs the first real handshake exposed, both fixed.** Auth issued integer
`sub` values and noted's seeds had claimed `auth_sub: "2"` for the leak-canary
account, so a real Google identity matched it and inherited its notes; auth's
ids are UUIDs now and the stub's subjects are namespaced `stub-N`. Separately the
stub minted tokens for the `Dev user 3` and `Dev user 4` fixtures, which auth
would have refused; the stub now refuses them the way auth does.

Suite: 195 examples, 0 failures.

## Next session, in this order

1. **The token-expiry hole in back-channel logout.** Auth notifies apps holding a
   *live* access token for a `sid`. Tokens last 15 minutes; a web session lasts 30
   days and nothing refreshes it. So signing out at auth more than 15 minutes
   after signing in at noted should silently fail to reach noted. Confirm with a
   test, then either keep notifying every app that ever held a token for that
   `sid`, or refresh on web requests.
2. **Golden fixtures (ADR 0003 M4).** Auth's suite freezes an access token, ID
   token, JWKS and logout token; a rake task copies them here; one spec verifies
   them through the real `TokenVerifier` and asserts the stub produces the same
   claim set. Both bugs above are the kind this catches.
3. **RP-initiated logout.** Signing out of noted ends only noted's session, so
   auth stays signed in and the next sign-in is silent — bad on a shared machine.
   Needs an `end_session_endpoint` in auth and a redirect here instead of a local
   destroy.
4. **Deploy auth** to `~/services/auth`:3001 — Capistrano, launchd, Pangolin,
   and the production redirect URI in the Google console. Last, because
   everything above churns its configuration.

Then back to milestone 10 (Android), which is where the work was before auth.

## Re-walk when auth changes

Two checks that are not obvious and not covered by a spec: `mise run server-oidc`
with auth on 3001 must round-trip through auth and land back on the board, and
signing out at `localhost:3001` must leave `LogoutDelivery.last` reading
`delivered` in mcn-auth with noted signed out. Everything else about sign-in is
in the suite.

## Android

The Compose client sends no token and will get `401` from a real server. Until it
runs AppAuth against auth, point it at `POST /dev/token` (stub mode only) — see
`clients/README.md`. Real-time sync (`SyncChannel` nudges, `CableClient`) and the
`/api/v1/changes` delta feed shipped in the previous session and are unchanged by
the auth work.

## Bugs

- Drag to move notes into folders isn't working.
- While writing a note, the save request triggers a websocket broadcast that
  reloads the page and closes the editor.
- `Api::V1::BaseController` is `ActionController::API`, which does not verify
  authenticity tokens, and it now accepts a cookie. Cross-site writes are blocked
  by the session cookie's `SameSite=Lax`, but that is the only thing blocking
  them — worth a deliberate look rather than a footnote.

## Milestones

| # | Deliverable | Status |
|---|---|---|
| 1 | Rails skeleton, models, migrations, seeds, `user_id` scoping | ✅ built |
| 2 | Tiled board, card design, masonry, CSS tokens | ✅ built |
| 3 | Editor modal, autosave, create-on-keystroke | ✅ built |
| 4 | Sidebar tree — folders, note rows, full-pane note, drag-to-file | ✅ built |
| 5 | Images — upload, gallery, thumbnails | |
| 6 | Calendar day stream — events, actions, rollover, day log, inline editing | |
| 7 | Auth — OIDC client of `auth`, sessions, bearer API (ADR 0003) | ✅ built |
| 8 | Search, archive, trash | |
| 9 | Tailscale, mise on the server, Capistrano deploy | ✅ built |
| 10 | Android — Compose client against `/api/v1` | ▶ in progress |
| 11 | Reminders | |
| 12 | Keep import | |
| 13 | Manual ordering — drag to reorder folders and notes | |
| 14 | Version history — read-only slider over past bodies | |
| 15 | macOS — SwiftUI client against `/api/v1` | |
| 16 | API catch-up — notes/folders over `/api/v1`, shared scoping concern, autosave repointed | ✅ built |

**Working order from here: finish the auth follow-ups above, then 10.** Remaining
server order is set by what the client needs, not by what is cheapest — which puts
the calendar (6) ahead of images (5).

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

1. ~~**Mail delivery.**~~ **Closed by ADR 0003.** noted has no password reset to
   stub and no address to verify — `auth` owns identity, and account recovery is
   Google's problem.
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
