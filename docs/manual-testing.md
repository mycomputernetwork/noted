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

## Android sign-in and folders

Needs auth on `:3001`, `mise run server-oidc`, and the `adb reverse` lines in
`clients/README.md`.

1. `cd clients/android && ./gradlew installDebug`; sign-in round-trips through the system browser.
2. `adb logcat | grep api/v1/session` shows one `200` for a first sign-in.
3. A new auth identity lands on an empty board and creates a noted account.
4. The board's bottom-right action is a plain `+`, not `+ Note`.
5. Open the drawer: folders show under a Folders heading with Edit and Create new folder rows.
6. Create a folder from the drawer, rename it from Edit folders, delete it, and confirm its notes move to No folder.
7. Sign out, then sign in again: auth asks for an identity and the local note cache is empty.

## Android editor back

1. Edit a note and leave with the toolbar arrow, then with the gesture/hardware back: both return to the board with the edit shown, and the web board shows it on reload.
2. Type and leave inside the 800ms autosave debounce: the edit still reaches the server.
3. Open a note, change nothing, leave: the sync icon spins but the note's `updated_at` is unchanged.
4. Open the new-note screen, leave without typing: no note appears on either board.

## Rate limiting

Throttles are off in test. Run `AUTH_MODE=stub mise run server`.

1. `for i in $(seq 25); do curl -s -o /dev/null -w "%{http_code} " localhost:3000/sign_in; done` — twenty `200`s, then `429`s with `retry-after: 60`.
2. `curl -i localhost:3000/up` still returns `200` while throttled.
3. `POST /auth/backchannel_logout` still returns through the safelist.
4. `/api/v1` throttles by bearer token, not address.

## Editor, board, and sidebar

1. Typing in the composer creates the note on the first keystroke and keeps saving without a page change.
2. Clicking away from the composer, Escape and Cmd/Ctrl+Enter each close it and
   leave the note on the board, selected. In both the composer and modal, type
   and press Cmd/Ctrl+Enter before the 800ms debounce: the card keeps the complete
   draft while the save finishes, without briefly reverting to an older body.
3. Closing an editor that was typed into and then emptied discards the note.
4. Card click opens the preloaded modal immediately, without a request in the
   Network panel; close it, then another card click opens the modal again.
   Closing is immediate while the header shows Saving… and then Saved. Its top
   sits above centre, and a long note still ends above the bottom edge — check
   at a short window height too.
5. Sidebar note click opens the full-pane note, not the modal.
6. The modal's expand icon opens the note's own page; text typed just before the
   click is already in the pane, the board never shows in between, and browser
   back lands on the board with no dialog left in it.
7. Drag a board card over another card in the same pinned/unpinned section; the grid makes room while dragging and the order survives reload.
8. Drag a card across the Pinned/Others boundary; it does not cross sections.
9. Drag a card or sidebar note row onto a folder row; it moves immediately to the top and stays there after reload.
10. Drag a sidebar note between two note rows; the insertion line position survives reload.
11. Drag a folder row above or below another folder; its notes move with it and the order survives reload.
12. Collapse a folder, reload, and it stays collapsed; a newly created folder starts open.

## Real-time sync

Two browsers, same account.

1. Editing a note in one browser updates and reflows that card in the other
   without a page request.
2. The board keeps its scroll position.
3. Writing a new note from the composer, or editing one in the modal, leaves that
   browser's own editor open and focused across every autosave.
4. A write to the open note from the other browser is held; its card updates
   once the editor closes.
