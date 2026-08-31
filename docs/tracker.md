# noted — tracker

Milestone status and where the work stands. This is the handoff target: it is
rewritten at the end of every session and read first at the start of one.
Milestone definitions and rationale live in the PRD; this is their live status.

_Last handoff: 31 Aug 2026._

## Where the work stands

**Milestone 7 (auth) is done, deployed and in daily use.** noted is a client of
`auth`, the fleet's OIDC provider at `~/work/services/auth` (ADR 0003). There are no
passwords: `users.auth_sub` is the identity of record, `sessions.sid` is what a
back-channel logout deletes, and `sessions.issuer` records which provider minted
a session so a stub one cannot survive a switch to the real one.

- **Web.** `/sign_in` runs Authorization Code + PKCE through
  `omniauth_openid_connect`. One button, and no `idp` hint: auth offers both
  Google and a password of its own, and which one a person uses is auth's page
  to ask about, not noted's. The callback verifies
  the ID token, finds or creates the account by `sub`, and mints noted's cookie
  session.
- **API.** `/api/v1` takes `Authorization: Bearer`, verified by `TokenVerifier`
  against auth's JWKS (cached 12h, refetched on an unknown `kid`). It also takes
  noted's cookie, because the web editor saves through the same endpoints. Two
  audiences are accepted: the web client's uid and the native client's, because
  a phone cannot hold the web client's secret and so is a client of its own.
- **Logout.** Signing out destroys noted's session, then hands the browser to
  auth's `end_session_endpoint` so auth's session ends too. Auth POSTs back to
  `/auth/backchannel_logout`, which verifies the logout token and deletes the
  session with that `sid`. Anything that redirects off-origin needs
  `data: { turbo: false }` — Turbo's fetch cannot follow one.
- **Development needs no auth service.** `mise run server` uses a stub issuer:
  identities from `config/dev_users.yml`, tokens signed with the keypair in
  `config/auth_stub/` and verified through the same code as production.
  `mise run server-oidc` swaps in the real provider on `:3001`. The initializer
  refuses to boot `stub` outside development and test.
- **Golden fixtures** (ADR 0003 M4) keep the stub honest. Auth freezes real
  tokens into `spec/fixtures/auth/golden.json`; `spec/models/golden_fixtures_spec.rb`
  verifies them through `TokenVerifier`/`LogoutToken` and compares the stub's
  claims to auth's. Refresh with `rake auth:golden_fixtures[../noted]` in auth.

## Production

Both apps run on dabba behind Pangolin: noted on `:3000`, auth on `:3001`, each
bound to loopback. `docs/DEPLOY.md` covers deploying, verifying a deploy, and
the failures that have happened before.

- **Credentials.** Production reads `config/credentials/production.yml.enc` —
  its own `secret_key_base`, and auth's issuer, client id, secret and the
  `noted-android` uid it accepts as a second audience. Both
  `.enc` files are in git; `production.key` is the only linked file and lives at
  `shared/config/credentials/` on the server.
- **Environment.** `NOTED_URL` builds the OIDC `redirect_uri` and must match
  what auth has registered. `SSL_CERT_FILE=/etc/ssl/cert.pem` gives the server's
  Ruby a CA store; without it every outbound HTTPS call fails.
- **Rate limiting.** `rack-attack` in both apps, per-process `MemoryStore`.
  `/api/v1` is throttled by bearer token so clients behind one address get a
  budget each; sign-in and everything else by address. `/up` and
  `/auth/backchannel_logout` are safelisted — auth's fan-out comes from one
  address for the whole fleet. Over the limit is 429 with `retry-after`.

The pre-auth account, which had no `auth_sub` and so could no longer be signed
into, was merged into the Google identity on 20 Aug. One user, nine notes.
Backup at `~/backups/noted/production-pre-account-merge.sqlite3` on dabba.

## Next session, in this order
1. **Decide the API CSRF question below.**

Also unfinished: nothing runs the backup script in `docs/DEPLOY.md` on a
schedule, 429 is missing from the API's swagger, and the launcher icon is still
the Compose-wizard default (source art is in `app/assets/images/`).

## Android

Signs in with Authorization Code + PKCE through AppAuth, against auth itself.
Tokens live in a Keystore-wrapped store; `POST /api/v1/session` creates the
account on a first sign-in, because the API resolves `auth_sub` and never
creates one. Sign-out revokes the refresh token, ends auth's session in the
device browser, and wipes the local cache — which is not scoped by user.

Development needs auth on `:3001` and `mise run server-oidc`: AppAuth cannot use
the stub issuer. `clients/README.md` has the two `adb reverse` lines. The debug
build allows cleartext and the release build does not, which is why a
release-shaped `ConnectionBuilder` in debug crashes on return from the browser.

Android releases come from `android-v*` tags. GitHub Actions signs the APK from
repository secrets, publishes `noted.apk` on the GitHub Release, and `/sign_in`
links to the latest public APK with version/date when GitHub's API answers.

Still to build for offline sync (ADR 0002): `deleted_at` tombstones on `folders`
and `day_logs`, and an `updated_at` index per synced table.

## Bugs

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
| 13 | Manual ordering — drag to reorder folders and notes | |
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

Closed: mail delivery and account recovery (ADR 0003), offline sync (ADR 0002),
and the Solid Cache/Queue schemas, which were empty in production until 20 Aug
(`docs/DEPLOY.md`).
