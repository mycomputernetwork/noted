# Working in this repo

noted is a self-hosted notes + calendar app: Rails 8, SQLite, Hotwire. 
The server lives at the repo root; native clients (Compose/Android, SwiftUI/macOS) 
live under `clients/` — see `clients/README.md`.

## Read these first, in order

1. `docs/tracker.md` — milestone status and where the work actually stands:
   what is known to be unexercised, what is next. Start here.
2. `docs/PRD.md` — what is being built and why. Written as argument, not
   specification; most decisions live here. Code comments cite it by section.
3. `docs/ADR/` — decision records for choices that reach outside the web app.

## Signing in

Sign-in is federated to the fleet's `auth` service (ADR 0003, and
`~/work/services/auth`). noted holds no passwords: `users.auth_sub` is the identity
of record, `sessions.sid` is what a back-channel logout deletes, and
`sessions.issuer` records which provider minted a session so a stub one cannot
survive a switch to the real one.

- `mise run server` — the daily loop. `AUTH_MODE=stub`: identities come from
  `config/dev_users.yml`, tokens are signed with the checked-in keypair in
  `config/auth_stub/` and verified through the same `TokenVerifier` as
  production. No auth service needs to be running.
- `mise run server-oidc` — the real handshake against `http://localhost:3001`.
  Use it when changing the handshake itself.
- `/api/v1` takes `Authorization: Bearer`, and also accepts noted's own cookie,
  because the web editor saves through those same endpoints. `POST /dev/token`
  hands a native client a real token in stub mode.
- Development identities are `Dev user 1`…`Dev user 4`. The third is refused by
  auth's allowlist and the fourth is revoked; the stub refuses them the way auth
  would. Seeds fill the first two, the second being a leak canary.
- Never seed or guess an `auth_sub`. Auth issues UUIDs; the stub's subjects are
  namespaced `stub-N`. A bare integer once matched a real account and handed it
  someone else's notes.

## Conventions

- **No frontend tests.** The suite is server-side only. `docs/manual-testing.md`
  covers the Stimulus controllers, the layouts and the cross-process auth flows.
  Keep it current as surfaces are added, and out of `docs/tracker.md`, which is
  rewritten each session.
- **Update `docs/tracker.md` at the end of every session.**
- Anything that changes a token claim, an endpoint auth calls, or the client
  registration belongs in `auth/docs/clients.md` as well as here.
- Avoid vague summarisations like "The line between the two surfaces" or "Small, and mostly rearrangement." No preambles like "Three faults surfaced when the deployed apps were first exercised against each other".
- Always Write manageable volumes of texts that are useful to both humans and agents. No code > Less code > Lots of code. No comments (i.e. write the code well) > small comments > lots of descriptive comments. Don't write any comments that restate the code, labels an obvious purpose, narrates structure, or explains why something isn't there. Don't cite PRD or ADR section numbers in code.
- Always review and update the swagger API docs, if any changes are made to APIs. Edit the rswag specs in spec/requests/api/, keep response shapes in the shared components/schemas in spec/swagger_helper.rb (never hand-edit swagger/v1/swagger.yaml), then run `bundle exec rake rswag:specs:swaggerize` — every operation needs a description, request-body fields need per-field descriptions, and every response needs a schema $ref.
