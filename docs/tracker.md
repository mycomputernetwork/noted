# noted — tracker

Milestone status and where the work stands. This is the handoff target: it is
rewritten at the end of every session and read first at the start of one.
Milestone definitions and rationale live in the PRD; this is their live status.

_Last handoff: 2 Sep 2026._

## Where the work stands

Feature branch/worktree: `frontend-review`, off `main` at `1550088`. A review
and cleanup pass over the web frontend, ready to merge back and remove the
worktree. Earlier work landed through `web-card-sidebar-proportions`.

The frontend went from 2,870 lines to 2,446, and comments from 485 lines to
~140. Nothing was meant to change on screen; the whole pass was dead code,
duplication and prose.

Deleted as unreachable: the `.nav*` block (dead since navigation moved into the
rail), `.card__body--untitled` (it set the colour `.card__body` already had),
`.rail__children[hidden]`, `modal#frame`, `board-order`'s `submitting` flag,
masonry's unused `gap` value, and the `row--untitled` and
`data-masonry-target="grid"` attributes, neither of which had a rule or a target.

The two layouts shared 24 identical head lines; those are now
`layouts/_head.html.erb`. The CSRF and header getters that existed in three
controllers are now `app/javascript/request.js`. `pane_controller.js` is gone —
it was only `preventSubmit`, which now sits on `autosave` alongside the other
three editor actions, declared once on the form in `notes/_fields` instead of on
each of the three wrappers. `create_url` went the same way: the form already
carries it as its `action`, so `autosave` reads `formTarget.action` and the
attribute is gone from all three surfaces.

Comments were cut against the rule in `AGENTS.md`. Every `PRD §n` citation is
out of the code; the arguments they pointed at were already written in the PRD.
The one piece of rationale that lived only in a comment — why the rail is
deliberately not `role="tree"` — moved into PRD §7.6 rather than being deleted.
What survives either names a trap (`.row__edit` using opacity, because
`display: none` would make rename keyboard-unreachable) or a cross-file coupling
(`--board-gap` is read by `masonry_controller.js`).

`spec/requests/sidebar_spec.rb` was targeting a row through `.row--untitled`, a
class with no stylesheet rule; it now selects by `href`.

`filing_controller` went from 375 lines to 213. It was re-implementing the rail
in JavaScript to move a row optimistically and put it back if the PATCH failed:
building `row__twist` spans by hand, re-deriving the folder pill by scraping the
sidebar's label, encoding the board's folder scope as a client-side predicate.
The drag still moves the row and, for a folder, its frame and children;
everything downstream of the move now arrives with the repaint, which goes
through `sync#flush` so there is one repaint path rather than two. A failed
write repaints as well, so the rollback machinery is gone rather than replaced.
User browser-tested filing and folder reordering after the change.

Web board polish is in user-approved shape. The page and cards share the same
lighter background, card bodies are white, card titles are 19px, card bodies are
15px with a 21px line box, masonry uses 240px minimum tracks with cards capped
at 330px, gutters are 14px, card borders are slightly brighter, card hover no
longer raises a shadow, and card/composer focus turns the element's own border
amber instead of drawing an inner outline.

Sidebar polish is in user-approved shape. The rail is back to its original
15.5rem width with slightly taller rows, sidebar note rows are 13px, folder/view
rows are 14px, untitled note rows are no longer dimmed, the footer note count is
gone, empty expanded folders render as blank space, an empty folder board shows
a `+ Create a note` link that opens/focuses the composer, and the sidebar glyphs
are inline Material Symbol-style SVGs with wider icon spacing only for the
material icons; folder carets keep their old width/gap and child-note indent.

Android feature picks 1 and 2 are built. The board's bottom-right action is a
plain `+` `FloatingActionButton`, not `+ Note`; the drawer has Keep-like folder
management; folder create, rename and delete are local-first and sync through the
existing folder API.

Every write carries an `X-Client-Id` header naming the tab that made it,
`SyncChannel` echoes it, and `sync` ignores its own echo — the first autosave of
a new note used to refresh the page over the composer being typed into.

The board no longer repaints off that echo. `sync` repaints on
`autosave:finalized`, so closing an editor puts its note on the board and the
composer back to a closed frame; a broadcast from another client repaints too,
unless an editor is open, in which case its close does it. Cmd/Ctrl+Enter now
closes the composer and the modal, alongside Escape, the backdrop and clicking
away — all of them one path, all of them save.

Masonry board ordering is implemented with `notes.board_position` for All Notes
and `notes.folder_board_position` for a note's current folder board, both
separate from the sidebar tree's `position`. Null All Notes positions fall back
to edited time; null folder positions fall back to `board_position` and then
edited time. New notes get a `board_position` before the current first note;
notes created in or moved into a folder get a `folder_board_position` before the
folder board's current first note.

The web board has no Edited/Created sort control. Dragging a card over another
card in the same pinned/unpinned zone moves it immediately and relayouts masonry;
dropping writes `PATCH /api/v1/notes/reorder`, with `folder_id` deciding which
order column changes. Dropping a card on a sidebar folder still uses filing,
which now puts the card at the front of that folder board. User browser-tested
the board before and after per-folder ordering and it looked good.

Android stores `boardPosition` and `folderBoardPosition`, migrates Room 1→3, and
supports long-press card reordering within the same pinned/unpinned zone. All
Notes reorder writes `boardPosition`; folder reorder writes `folderBoardPosition`.
The board renders Pinned and Others/Notes sections like web and uses an amber
selected border.

Review follow-ups now remove stale Android card bounds when cards leave
composition, keep folder-deletion note updates visible to cursor sync and
broadcast callbacks, and clear folder-specific board positions when notes
become unfiled.

Specs pass: `bundle exec rspec` (2 Sep 2026). Swagger was regenerated earlier
with `bundle exec rake rswag:specs:swaggerize`. Android compile/unit task passes:
`cd clients/android && ./gradlew testDebugUnitTest`. Debug app was installed and
user-tested on the emulator.
Also unfinished: nothing runs the backup script in `docs/DEPLOY.md` on a
schedule, and 429 is missing from the API's swagger.

The Android app draws the wordmark from `res/drawable-nodpi/` (`ui/Logo.kt`,
tinted `onSurface`) in the board's app bar, and boiling on the sign-in screen —
the gif's three frames as PNGs on a timer, because Compose decodes no gif.
Re-exporting `noted_white-boil.gif` means re-exporting `noted_wordmark_boil_*`.

The launcher icon and the web favicon are both the amber mark from
`app/assets/images/` — adaptive icon in `clients/android/.../res/mipmap-*`,
`public/{favicon.ico,icon.png,apple-touch-icon.png}` linked from both layouts.
Both seen on the emulator from a debug build.

## Android

Signs in with Authorization Code + PKCE through AppAuth, against auth itself.
Tokens live in a Keystore-wrapped store; `POST /api/v1/session` creates the
account on a first sign-in, because the API resolves `auth_sub` and never
creates one. Sign-out revokes the refresh token, ends auth's session in the
device browser, and wipes the local cache — which is not scoped by user.

Still to build for offline sync (ADR 0002): `deleted_at` tombstones on `folders`
and `day_logs`, and an `updated_at` index per synced table.

## Features to pick

## Bugs
- i dont want turbo to load notes for the modal on demand when it's hovered/clicked. preload all the notes so the modal opens instantly, right now there's a big delay. if there's any updates happening from another device they'll get broadcasted anyways.
- why does everyone get signed out after every deploy? does it even happen.
- remove yellow circle highlight on pin icon inside a note. just white fill, no circle around it.

### lower priority
- auth strands `prompt=select_account`: `select_account_for_resource_owner`
  redirects to its sign-in page, which bounces a signed-in visitor to root.
  `prompt=login` works.
- `Api::V1::BaseController` is `ActionController::API`, so it verifies no
  authenticity token, and it accepts noted's cookie. `SameSite=Lax` is the only
  thing stopping a cross-site write. noted is on a public hostname now, so this
  wants a decision.

## Milestones

| # | Deliverable | Status |
|---|---|---|
| 1 | Rails skeleton, models, migrations, seeds, `user_id` scoping | ✅ built |
| 2 | Tiled board, card design, masonry, CSS tokens | ✅ built |
| 3 | Editor modal, autosave, create-on-keystroke | ✅ built |
| 4 | Sidebar tree — folders, note rows, full-pane note, drag-to-file | ✅ built |
| 6 | Calendar day stream — events, actions, rollover, day log, inline editing | |
| 11 | Reminders | |
| 7 | Auth — OIDC client of `auth`, sessions, bearer API (ADR 0003) | ✅ built |
| 8 | Search, archive, trash | |
| 9 | Deploy — mise on the server, Capistrano, Pangolin | ✅ built |
| 10 | Android — Compose client against `/api/v1`, signed in through auth | ✅ built |
| 12 | Keep import | |
backups
| 13 | Manual ordering — drag to reorder folders and notes | ✅ built |
| 14 | Version history — read-only slider over past bodies | |
| 15 | API catch-up — notes/folders over `/api/v1`, shared scoping concern, autosave repointed | ✅ built |

**Working order from here: the remaining server milestones.** Their order is set
by what the clients need, not by what is cheapest — which puts the calendar (6)
ahead of images (5).

## Open questions

1. **Storage visibility surface.** Is a plain settings figure enough, or is a
   small owner-facing view across all users wanted?
2. **Completed actions on a past day.** Once a day is in the past, should its
   completed actions stay in the stream or collapse into a count? Only matters
   once there is enough history to scroll through.
3. **Search across types.** Results are grouped by type. Whether a day-entry hit
   links into the calendar at that day or opens something modal is undecided
   until milestone 8.
