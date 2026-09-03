# noted — tracker

Milestone status and where the work stands. This is the handoff target: it is
rewritten at the end of every session and read first at the start of one.
Milestone definitions and rationale live in the PRD; this is their live status.

_Last handoff: 3 Sep 2026._

## Where the work stands

**Working order from here: the remaining server milestones.** One
`NoteEditSession` owns an editor's draft and revisions; its open editor owns the
note through its final save, then releases queued remote changes. The preloaded
modal, optimistic board updates, and Cmd/Ctrl+Enter flow have been exercised.

Cards now carry their own pin control, top right, shown on hover; it PATCHes `note[pinned]` and reuses the board's upsert to move the
card between sections. Unverified in a browser — steps 13–14 of
`docs/manual-testing.md`.

The remaining milestone order is set by what the clients need, which puts the
calendar (6) ahead of images (5).

## Android
Signs in with Authorization Code + PKCE through AppAuth, against auth itself.
Tokens live in a Keystore-wrapped store; `POST /api/v1/session` creates the
account on a first sign-in, because the API resolves `auth_sub` and never
creates one. Sign-out revokes the refresh token, ends auth's session in the
device browser, and wipes the local cache — which is not scoped by user.

Leaving the editor — toolbar arrow or system back — saves and then pushes, in
that order and on `viewModelScope`, so an edit made inside the autosave debounce
survives the screen's composition being torn down.

Still to build for offline sync (ADR 0002): `deleted_at` tombstones on `folders`
and `day_logs`, and an `updated_at` index per synced table.

## Features to pick
- we can put a cloud icon on the top right (like the android app does) to show sync status (and i want to remove the turbo link blue progress bar on top and replace with setting the cloud spinner while any turbo activity is happening also).

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

## Open questions

1. **Storage visibility surface.** Is a plain settings figure enough, or is a
   small owner-facing view across all users wanted?
2. **Completed actions on a past day.** Once a day is in the past, should its
   completed actions stay in the stream or collapse into a count? Only matters
   once there is enough history to scroll through.
3. **Search across types.** Results are grouped by type. Whether a day-entry hit
   links into the calendar at that day or opens something modal is undecided
   until milestone 8.
