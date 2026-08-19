# noted

A self-hosted personal notes and calendar application. Uses Rails 8, SQLite, Hotwire.

## Documentation

Everything authoritative lives in the repo, not in any external note:
- AGENTS.md
- docs/tracker.md - Milestone status and where the work stands.
- docs/manual-testing.md - The checks to walk by hand.
- docs/PRD.md
- clients/README.md - The native Compose (Android) and SwiftUI (macOS) clients.

## Getting started

```sh
mise install        # installs the Ruby pinned in .mise.toml
mise run setup      # gems into vendor/bundle, database, seeds
mise run server     # http://localhost:3000
mise run test       # the RSpec suite
```

Then open http://localhost:3000. `mise exec --` is only needed if mise isn't
activated in your shell; add `eval "$(mise activate zsh)"` to `~/.zshrc` to drop
it. Check with `ruby -v` (expect 3.4.10) and `bundle -v` (expect 2.6+) — a lower
bundler means you're still on the system Ruby and the Gemfile's `ruby file:`
directive will fail first.

## Signing in

Sign-in is federated to the fleet's `auth` service (`docs/ADR/0003`), but
development does not need it running. `mise run server` uses a stub issuer: the
sign-in page lists the fixture identities in `config/dev_users.yml`, and tokens
are signed with a checked-in keypair and verified through the same code path as
production. Seeds create content for the first two — `dev1@example.com` and
`dev2@example.com`, the latter a leak canary. The other two exist to be
refused, as `auth` would refuse them.

`mise run server-oidc` swaps in the real provider on `http://localhost:3001`,
which is `~/work/mcn-auth`. Use it when changing the handshake itself; the
steps are in `docs/manual-testing.md`.

The API takes `Authorization: Bearer` and returns `401` without it. `POST
/dev/token` with `email=dev1@example.com` returns a usable token in stub mode,
which is how the native clients work locally.
