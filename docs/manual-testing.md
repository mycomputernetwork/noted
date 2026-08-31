# Manual testing

Only checks that need a browser, device, real provider, throttles, or two live
clients. Request specs cover the server contracts.

Run `mise run setup` once. Use `mise run server` unless a section says otherwise.

## Web sign-in smoke

1. Signed out, `/` redirects to `/sign_in`; stub mode shows four dev identities.
2. **Dev user 1** opens the seeded board; the header shows the account and signs out.
3. **Dev user 2** shows only the leak-canary account's folder and note.

## Real auth sign-in

Needs `~/work/services/auth` on `:3001`; run `mise run server-oidc` here.

1. `/sign_in` shows one Sign in button and lands on auth.
2. Google and password sign-in both return to noted's board.
3. `bin/rails runner 'pp User.pluck(:email, :auth_sub)'` shows UUID subjects.
4. Signing out from auth signs noted out on reload.
5. Signing out from noted visits auth's logout endpoint and returns to `/sign_in`; signing in again asks auth for an identity.

## Android sign-in

Needs auth on `:3001`, `mise run server-oidc`, and the `adb reverse` lines in
`clients/README.md`.

1. `cd clients/android && ./gradlew installDebug`; sign-in round-trips through the system browser.
2. `adb logcat | grep api/v1/session` shows one `200` for a first sign-in.
3. A new auth identity lands on an empty board and creates a noted account.
4. Sign out, then sign in again: auth asks for an identity and the local note cache is empty.

## Rate limiting

Throttles are off in test. Run `AUTH_MODE=stub mise run server`.

1. `for i in $(seq 25); do curl -s -o /dev/null -w "%{http_code} " localhost:3000/sign_in; done` — twenty `200`s, then `429`s with `retry-after: 60`.
2. `curl -i localhost:3000/up` still returns `200` while throttled.
3. `POST /auth/backchannel_logout` still returns through the safelist.
4. `/api/v1` throttles by bearer token, not address.

## Editor, board, and sidebar

1. Typing in the composer creates the note on the first keystroke and keeps saving without a page change.
2. Closing an editor that was typed into and then emptied discards the note.
3. Card click opens the modal; close it, then another card click opens the modal again.
4. Sidebar note click opens the full-pane note, not the modal.
5. Drag a card or sidebar note row onto a folder row; it moves immediately to the top and stays there after reload.
6. Drag a sidebar note between two note rows; the insertion line position survives reload.
7. Drag a folder row above or below another folder; its notes move with it and the order survives reload.
8. Collapse a folder, reload, and it stays collapsed; a newly created folder starts open.

## Real-time sync

Two browsers, same account.

1. Editing a note in one browser repaints the board in the other.
2. The morph keeps scroll position and does not close an open editor or composer.
