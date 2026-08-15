# notbuk

A self-hosted personal notes and calendar application. Uses Rails 8, SQLite, Hotwire.

## Documentation

Everything authoritative lives in the repo, not in any external note:
- AGENTS.md
- docs/tracker.md - Milestone status and where the work stands.
- docs/PRD.md
- clients/README.md - The native Compose (Android) and SwiftUI (macOS) clients.

## Getting started

```sh
mise install                  # installs the Ruby pinned in .mise.toml
mise exec -- bundle install   # gems land in vendor/bundle, not user-wide
mise exec -- bin/rails db:prepare
mise exec -- bin/rails test
mise exec -- bin/rails server
```

Then open http://localhost:3000. `mise exec --` is only needed if mise isn't
activated in your shell; add `eval "$(mise activate zsh)"` to `~/.zshrc` to drop
it. Check with `ruby -v` (expect 3.4.10) and `bundle -v` (expect 2.6+) — a lower
bundler means you're still on the system Ruby and the Gemfile's `ruby file:`
directive will fail first.

Seeds create data under user `me@notbuk.local` (password `notbuk-dev-password`).
