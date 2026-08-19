# 0003 — A centralized auth service, federated over OIDC

**Status:** Accepted, 2026.

## Context

noted is the first of a small fleet of self-hosted services on the same
machine — `auth`, `noted`, `chat` as Rails apps sharing the deploy conventions
in `docs/DEPLOY.md`, plus `photos` (Immich) and `watch` (Jellyfin) as
non-Rails services fronted by the same reverse proxy. Each Rails app needs
sign-in, some will grow native companions (`clients/README.md`), and the
identity provider is Google in every case. The question this record settles:
does each app integrate with Google directly, or does one service own that
integration and everything else trusts it.

## Decision

**One `auth` app is the only thing that talks to Google.** It is a small
OIDC provider (`doorkeeper` + `doorkeeper-openid_connect`), with
`omniauth-google-oauth2` as its sole upstream. Every other app — web or
native — authenticates against `auth.mycomputer.network`, never against
Google. `auth` is the one place an email allowlist is enforced and the one
place a user's access can be revoked fleet-wide.

**Resource servers verify JWTs locally, against auth's published JWKS.**
`auth` signs tokens with its own key and serves the public half at
`/.well-known/jwks.json`. noted and chat cache that key set and verify
signatures offline — no network call to auth on the request path, only on
token refresh. This is what keeps auth from becoming a single point of
failure for every request across the fleet, at the cost of a revocation
delay bounded by the access token's lifetime (short, ~15 minutes, by
design — see Consequences).

**Web apps get a first-party session, not a shared cookie.** After the OIDC
callback, each app mints its own session cookie scoped to its own host,
keyed by the `sub` claim from auth — auth's own user id, not Google's.
Google's `sub` stays inside auth as the lookup key for the upstream
callback, so a re-linked Google account does not change the identity every
downstream app has stored. Apps do not share
`secret_key_base` or a cookie domain across `*.mycomputer.network` — that
would couple every app's session security to every other app's. Federation
happens at the token layer, not the cookie layer.

**Native apps use Authorization Code + PKCE against auth**, not against
Google and not embedding a client secret. AppAuth on Android,
`ASWebAuthenticationSession` on macOS. The result is a short-lived access
token plus a refresh token, stored in Keychain/Keystore, sent as
`Authorization: Bearer` to each app's API — the same bearer-verification
code path a browser-derived session eventually reduces to when an app also
exposes an API (ADR 0001).

**Single sign-on comes from auth's own session, not from each app's.** auth
sets a session cookie on its own domain when Google's callback lands. A
second app's `/authorize` redirect finds that cookie already present and
mints a token silently — no second Google prompt. This is what makes SSO
"log in once" rather than "log in once per app."

**Single logout is back-channel, not front-channel.** `auth/logout` makes
direct server-to-server POST requests to each registered app's
`backchannel_logout_uri`, carrying a signed logout token identifying the
session to kill; each app deletes that session from its own store. Rejected
the iframe-based front-channel variant — it depends on third-party cookies
loading in a hidden iframe, which Safari's ITP and Chrome's phase-out
increasingly block even for same-operator domains. Back-channel logout means
sessions can no longer be purely stateless signed cookies: each app needs a
server-side session record keyed by the OIDC `sid` claim for the logout
call to find and delete.

## Alternatives

- **Each app integrates with Google directly.** The default OmniAuth
  tutorial setup. Rejected: five separate Google Cloud console apps to
  rotate credentials for, five places to enforce an allowlist, no way to
  revoke a user across the fleet in one action, and native apps would be
  left using Google ID tokens as ongoing API auth — not what they're for.
- **A shared cookie domain (`*.mycomputer.network`) instead of per-app
  tokens.** Cheaper to build, but ties every app's session secret and
  cookie security to the others', and gives native apps nothing — they
  don't have a shared browser cookie jar with the web apps by default.
- **Front-channel (iframe) logout.** Simpler to implement than back-channel,
  but unreliable against current browser third-party cookie restrictions;
  would silently stop working on some fraction of logouts with no error
  visible to the user.

## Consequences

- New services join the fleet by registering an OAuth client with `auth` and
  adding JWT verification middleware — no new Google credentials, no new
  allowlist to maintain.
- Revoking a user is one action at `auth`: refresh tokens die immediately
  (checked server-side on every refresh), access tokens die within their
  TTL. The TTL is chosen deliberately short (~15 min) because that is the
  actual exposure window between an access token being valid and auth being
  able to say otherwise.
- Sessions in every downstream app become server-side records (session id →
  user), not pure stateless cookies, because back-channel logout needs
  something to delete. This is a small schema addition per app
  (`sessions` table, `sid` claim as the lookup key), not a redesign.
- `auth` becomes infrastructure every other app depends on for login. It
  gets the same deploy treatment as any other service in the fleet (own
  port, own `~/services/auth`, own launchd label per `docs/DEPLOY.md`) —
  it is not special-cased infrastructure, just deployed first.
- Native clients gain a real bearer-token API auth story instead of
  improvising one per app; `clients/README.md` gets a PKCE integration
  section once this lands.

## Implementation

The service is `mcn-auth`, developed at `~/work/mcn-auth` and deployed to
`~/services/auth` on port 3001 under the conventions in `docs/DEPLOY.md`:
Rails 8, SQLite, no Node, `master.key` in `shared/config`, one Pangolin
resource for `auth.mycomputer.network`. The RS256 signing key lives in
encrypted credentials, which puts it in the deploy path already protected.

### Milestones

**M1 — skeleton and the Google upstream.** `users` (`google_sub` unique,
`email`, `name`, `revoked_at`), `sessions`, and `allowed_emails` as a table
rather than a config constant, so revoking access is a `rails runner` away
and not a redeploy. The OmniAuth callback finds or creates a user and turns
away anything not on the list. auth's session is a server-side row from the
start, because both silent SSO and the `sid` anchor for logout depend on it.

**M2 — the OIDC provider.** Doorkeeper and `doorkeeper-openid_connect`,
with `resource_owner_authenticator` reading auth's session and redirecting
to Google when it is absent. Access tokens live 15 minutes, refresh tokens
rotate, and every refresh checks `revoked_at` server-side — that check is
what makes the short TTL meaningful. Request specs cover the discovery
document, the JWKS shape, an authorize/code/token exchange with PKCE,
refresh rotation, and a refresh after revocation.

**M3 — clients and back-channel logout.** `oauth_applications` gains a
`backchannel_logout_uri`; native clients are registered public, PKCE-only,
without a secret. `/logout` drops auth's session and then POSTs a signed
logout token to every app holding a live session for that `sid`. Deliveries
are recorded so a failed POST is visible rather than leaving a session alive
somewhere in the fleet.

**M4 — the resource-server side.** A `TokenVerifier` (JWKS fetch, cache,
signature and claim verification), a `sessions` table keyed by `sid`, and a
back-channel logout controller, copied into each app as a vendored file
rather than published as a private gem. At three apps copying is cheaper
than versioning; that trade is worth revisiting at five.

**M5 — noted as the first client.** noted gets the OIDC client, the session
table, and bearer verification on `/api`. Until this lands, none of the
above has been exercised by a real consumer.

### Development

Downstream apps default to a stub issuer in development and test: a fixture
list of users in `config/dev_users.yml`, a dev-only sign-in page to pick
between them, and a `sign_in_as(:family)` spec helper that mints a token
directly with a checked-in keypair. Fixtures include a non-allowlisted and a
revoked user, since those rejection paths are otherwise awkward to reach.
The whole stub sits behind `Rails.env.local?` and an explicit `AUTH_MODE`,
loaded from an initializer that refuses to boot in production.

This keeps noted's daily loop free of a second running process, a Google
round-trip, and a network dependency, at the cost of not exercising the
handshake. Two things pay that cost back. Auth's own request specs cover the
protocol end of it without any downstream app involved. And auth's suite
mints golden fixtures — a real access token, id token, JWKS, and logout
token, frozen in time — which a rake task copies into each downstream repo,
where one spec verifies them through the real `TokenVerifier` and asserts
the stub produces the same claim set. Adding a claim to auth without
recopying turns that spec red. Without the golden fixtures the stub is free
to drift and the arrangement is not safe.

Working on the handshake itself means running the real provider:
`AUTH_MODE=oidc AUTH_ISSUER=http://localhost:3001`, with both apps started
from a fleet Procfile. Client credentials are deterministic in development —
auth seeds a fixed uid and secret, noted's development credentials carry the
matching pair — so a fresh clone works without either repo reading the
other's database. Sign-in at auth uses the same dev picker, so this needs no
Google credentials on a development machine.

Rejected a scripted cross-app smoke test. It automates a minute of clicking
that is needed only when auth integration changes, and would rot between
those occasions; the click-through list in `docs/tracker.md` carries the
steps instead. Also rejected pointing development at the deployed auth,
which buys nothing over a local provider and accumulates `localhost`
redirect URIs in production configuration.

## Out of scope

- **Detail below the milestone level.** Implementation sketches the shape
  and the order; schema, routes, and gem configuration are settled in
  `mcn-auth` itself.
- **Multi-tenancy or invite flows.** The allowlist is a fixed set of emails
  for personal/family use, not a signup product.
