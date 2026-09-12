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

## Android board drag

1. Long-press a card and move slowly: the card lifts and tracks the finger from the first pixel, above its neighbours, without waiting to cross into another card.
2. Drag over another card in the same section: the others make room, and the dragged card stays under the finger across the reorder. Hold it still over the gap below a short card next to a tall one: the board still reorders, and repeated small moves settle rather than reshuffling on every frame.
3. Drag across the Pinned/Others boundary: the card follows the finger but does not change section.
4. Release: the card settles into its slot and the order survives a restart.
5. Reorder, then reorder again while the sync icon is still spinning: the second
   order is what stays, on the board and after a restart. Throttle the network
   to widen the window.
6. Reorder with the device offline, then reconnect: the offline order reaches the
   server rather than being replaced by the last one it saw.

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
4. Card click expands the preloaded modal's surface from that card's position
   and size, then fades in stationary text; no visible text stretches, moves or
   rewraps. The backdrop fades rather than flashing on. There is no request in
   the Network panel. Check cards in different columns and after scrolling,
   including a long note at a short window height. Escape, Close, backdrop click
   and Cmd/Ctrl+Enter fade the text out, then shrink the surface back into its
   card; the final draft saves. Close during opening, press Escape repeatedly,
   then open another card: no leftover transform or hidden text. The source
   stays invisible in its masonry slot until close, including across autosaves.
   Change the note's length or pin state, wait for autosave, then close: it returns
   to the card's current bounds. Moving it out of the folder board closes without
   flying to a missing card. Reduced motion makes opening and closing instant.
   Navigate away and back: no card remains hidden.
5. Sidebar note click opens the full-pane note, not the modal.
6. The modal's expand icon opens the note's own page; text typed just before the
   click is already in the pane, the board never shows in between, and browser
   back lands on the board with no dialog left in it.
7. Drag a board card over another card in the same pinned/unpinned section; the grid makes room while dragging and the order survives reload. Hold the card still mid-drag: the other cards settle and stay put. A short card and a tall one respond the same, including in the empty space a short card leaves below it.
8. Drag a card across the Pinned/Others boundary; it does not cross sections.
9. Drag a card or sidebar note row onto a folder row; it moves immediately to the top and stays there after reload.
10. Drag a sidebar note between two note rows; the insertion line position survives reload.
11. Drag a folder row above or below another folder; its notes move with it and the order survives reload.
12. Collapse a folder, reload, and it stays collapsed; a newly created folder starts open.
13. Hover a card: a small white circle and tick appear over the top-left corner,
    while its pin and three-dot controls appear at the top right. The three-dot
    menu opens outside the card and contains only the smaller `Delete note` text.
    On a card against the viewport's right edge it flips inward and remains fully
    visible. Move off the card: all three controls hide. Keyboard focus still
    reveals them.
14. Click the pin; the card moves between Pinned and Others without opening the
    modal, survives reload, and opens with the editor's pin already checked.
15. Check one card: it gains a white border and the header shows `1 selected`
    with a three-dot delete menu. Click other cards to add or remove them without
    opening the modal. Clear selection with Escape and with the header close button.
16. Open a card's three-dot menu and delete it. It leaves the board and sidebar
    without a confirmation, and a bottom-left `Note trashed` toast spans the
    sidebar's inner width and offers Undo. Let it time out once and confirm it
    fades downward, then repeat and click Undo: the card and sidebar row return
    in place and survive reload.
17. Select notes from both Pinned and Others, delete them from the header menu,
    and confirm every selected card and sidebar row leaves while unselected cards
    stay. The toast reports the count and restores the whole batch with Undo.
    Repeat on a folder board.

## Trash

1. Open Trash from the sidebar. It lists only trashed notes, newest deletion
   first, and explains that nothing is deleted automatically.
2. Restore one note. It leaves Trash, returns to the sidebar and is present on
   the Notes board after navigation and reload.
3. Choose Delete forever on one note. Cancel the confirmation once, then accept
   it; only that note is permanently removed.
4. Empty trash is visibly styled as a button. Choose it, cancel once, then accept
   it; all remaining trashed notes are permanently removed and the empty state
   replaces the grid.

## Modal URLs

1. Open a card: the address gains `?note=<UUID>` without a page request or scroll
   jump. Close it: only `note` disappears; no extra browser-history entry is added.
2. While signed in, paste that URL into a new tab and reload it: the same note
   opens in the modal, without flying in from an off-screen card.
3. Repeat on a folder board with a different calendar year selected: folder and
   year survive opening, copying, reloading and closing.
4. Copy a folder modal URL, move its note to another folder, then load the copied
   URL: the modal still opens, without adding a card to the old folder's board.
5. Edit, close before debounce, and immediately open another card: its UUID ends
   up in the address, the first draft saves, and neither note replaces the other.
6. Expand to full view, then go Back: the board returns without a modal. Navigate
   away with a modal open, then Back: the URL's note opens again. Repeat after a
   folder change from another client triggers a board refresh.

## Real-time sync

Two browsers, same account.

1. Editing a note in one browser updates and reflows that card in the other
   without a page request.
2. The board keeps its scroll position.
3. Writing a new note from the composer, or editing one in the modal, leaves that
   browser's own editor open and focused across every autosave.
4. A write to the open note from the other browser is held; its card updates
   once the editor closes.
