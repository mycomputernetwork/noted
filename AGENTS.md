# Working in this repo

notbuk is a self-hosted notes + calendar app: Rails 8, SQLite, Hotwire. 
The server lives at the repo root; native clients (Compose/Android, SwiftUI/macOS) 
live under `clients/` — see `clients/README.md`.

## Read these first, in order

1. `docs/tracker.md` — milestone status and where the work actually stands:
   what to click first, what is known to be unexercised, what is next. Start here.
2. `docs/PRD.md` — what is being built and why. Written as argument, not
   specification; most decisions live here. Code comments cite it by section.
3. `docs/ADR/` — decision records for choices that reach outside the web app.

## What cannot be driven from a cloud session

- **Git can't go through the Cowork device bridge** — it leaves `.git/*.lock`
  files it can't remove. Write the commit message and hand the command to prabh
  to run, or start the task on his computer via the desktop app's "Run this
  task" picker.
- **There is no Ruby in the device VM**, so the suite can't run from a cloud
  session. Hand over `mise exec -- bin/rails test` and wait for the result
  rather than claiming code works.

## Conventions

- Don't quote PRD sections (for ex. according to PRD  §18) in code comments or anywhere.
- **No frontend tests, decided.** The suite is server-side only. The
  click-through list in `docs/tracker.md` is the regression suite for the
  Stimulus controllers — keep it current as surfaces are added.
- **Update `docs/tracker.md` at the end of every session.**
- Avoid vague summarisations like "The line between the two surfaces" or "Small, and mostly rearrangement."
- Write manageable volumes of texts that are useful to both humans and agents. No code > Less code > Lots of code. No comments (i.e. write the code well) > small comments > lots of descriptive comments.
