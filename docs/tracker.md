# noted — tracker

Milestone status and where the work stands. This is the handoff target: it is
rewritten at the end of every session and read first at the start of one.
Milestone definitions and rationale live in the PRD; this is their live status.

_Last handoff: 1 Sep 2026._

## Where the work stands

Feature branch/worktree: `feature/masonry-ordering` at
`~/work/worktrees/noted/feature-masonry-ordering`.

Masonry board ordering is implemented with `notes.board_position`, separate from
the sidebar tree's `position`. Existing rows may stay null; the first board drag
submits every visible card id and writes positions. New notes get a
`board_position` before the current first note.

The web board has no Edited/Created sort control. Dragging a card over another
card in the same pinned/unpinned zone moves it immediately and relayouts masonry;
dropping writes `PATCH /api/v1/notes/reorder`. Dragging across Pinned/Others does
not cross zones. Dropping a card on a sidebar folder still uses filing.

Android stores `boardPosition`, orders by it, migrates Room 1→2, and supports
long-press card reordering within the same pinned/unpinned zone. Reorders mark
notes dirty and sync through the existing note update path.

Specs pass: `bundle exec rspec`. Android compile/unit task passes:
`cd clients/android && ./gradlew testDebugUnitTest`.

## Next session, in this order
1. Browser-check board drag on the worktree server.
2. Emulator-check Android long-press reorder.
3. Decide the API CSRF question below.

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
- in the + Note on home page, remove the text "Note", just + is enough
- folder management in android.

## Bugs
- i dont want turbo to load notes for the modal on demand when it's hovered/clicked. preload all the notes so the modal opens instantly, right now there's a big delay. if there's any updates happening from another device they'll get broadcasted anyways.
- make the notes text a little smaller and the sidebar a little bigger, proportions are off.(ask user for screenshot). keep the note's text in the note card white (not grey).
- why does everyone get signed out after every deploy? does it even happen.

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
| 5 | Images — upload, gallery, thumbnails | |
| 6 | Calendar day stream — events, actions, rollover, day log, inline editing | |
| 7 | Auth — OIDC client of `auth`, sessions, bearer API (ADR 0003) | ✅ built |
| 8 | Search, archive, trash | |
| 9 | Deploy — mise on the server, Capistrano, Pangolin | ✅ built |
| 10 | Android — Compose client against `/api/v1`, signed in through auth | ✅ built |
| 11 | Reminders | |
| 12 | Keep import | |
| 13 | Manual ordering — drag to reorder folders and notes | ✅ built |
| 14 | Version history — read-only slider over past bodies | |
| 15 | macOS — SwiftUI client against `/api/v1` | |
| 16 | API catch-up — notes/folders over `/api/v1`, shared scoping concern, autosave repointed | ✅ built |

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
