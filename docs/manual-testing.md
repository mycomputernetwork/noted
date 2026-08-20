# Manual testing

Checks to walk by hand. The suite covers no Stimulus controller, no layout and
no cross-process flow.

## Sign-in

Run `mise run setup` first — the seeded accounts are the first two fixture
identities, so the picker lands on real content.

1. Signed out, `/` redirects to `/sign_in`, which lists four development
   identities and no Google button.
2. **Dev user 1** → the board, with the seeded folders and notes.
3. The account menu in the header shows the signed-in email; **Sign out** →
   `/sign_in`. That is how you switch identities.
4. **Dev user 2** → the leak canary: one folder, one note, and none of Dev user
   1's content. Anything of Dev user 1's appearing here is a scoping bug.
5. **Dev user 3** → refused, not allowlisted. **Dev user 4** → refused, revoked.
   Neither creates a session.

## Sign-in against the real provider

Needs `~/work/mcn-auth` running on 3001. Walk this whenever the handshake, the
token claims or the logout path change — it is the part no spec can reach.

1. `mise run server-oidc`. `/sign_in` shows one Login with Google button, no
   picker.
2. It round-trips through auth's own sign-in and lands back on noted's board.
   Locally auth still shows its page — the `idp=google` hint noted sends is
   ignored in development so the dev picker stays reachable. Deployed, that
   page is skipped and the browser goes straight to Google.
3. `bin/rails runner 'pp User.pluck(:email, :auth_sub)'` — the subject is a
   UUID. A small integer means auth is issuing the old format and a collision is
   possible.
4. Sign out at `localhost:3001`, then reload noted: signed out here too.
5. In mcn-auth, `LogoutDelivery.last` reads `delivered`. `failed` means the POST
   never arrived; `rejected` means noted refused the token.
6. Sign in again, then **Sign out** from noted's account menu: the browser goes
   through `localhost:3001/oauth/logout` and comes back to noted's `/sign_in`.
   Signing in again now asks auth for an identity rather than returning
   silently — auth's own session is gone too. Landing on auth's sign-in page
   instead of noted's means the `post_logout_redirect_uri` auth has registered
   for the client is not `http://localhost:3000/sign_in`.

## Rate limiting

Throttles are off in test and counted per process, so only a running server
shows them. `AUTH_MODE=stub mise run server`, then:

1. `for i in $(seq 25); do curl -s -o /dev/null -w "%{http_code} " localhost:3000/sign_in; done`
   — twenty 200s, then 429s carrying `retry-after: 60`.
2. `curl -i localhost:3000/up` still returns 200 while that address is
   throttled, and so does a `POST /auth/backchannel_logout`. Both are safelisted
   because a health check and auth's logout fan-out must not be sheddable.
3. `/api/v1` counts against the bearer token, not the address: two clients on
   one connection get a budget each. Restart the server to clear the counters.

## Editor and board

Milestone 3 and 4 surfaces. These have no specs beyond the markup assertions.

1. Typing in the composer creates the note on the first keystroke and keeps
   saving without a page change.
2. Closing an editor that was typed into and then emptied discards the note.
3. Dragging a card onto a folder row in the sidebar files it, optimistically,
   and it stays filed after a reload.
4. Collapsing a folder survives a reload (`localStorage`), and a folder created
   afterwards is open by default.

## Real-time sync

Milestone 10. Two browsers, same account.

1. Editing a note in one repaints the board in the other within a second or so.
2. The morph keeps scroll position and does not close an open editor.
