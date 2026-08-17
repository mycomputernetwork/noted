# Working in this repo

noted is a self-hosted notes + calendar app: Rails 8, SQLite, Hotwire. 
The server lives at the repo root; native clients (Compose/Android, SwiftUI/macOS) 
live under `clients/` — see `clients/README.md`.

## Read these first, in order

1. `docs/tracker.md` — milestone status and where the work actually stands:
   what to click first, what is known to be unexercised, what is next. Start here.
2. `docs/PRD.md` — what is being built and why. Written as argument, not
   specification; most decisions live here. Code comments cite it by section.
3. `docs/ADR/` — decision records for choices that reach outside the web app.

## Conventions

- **No frontend tests** The suite is server-side only. The
  click-through list in `docs/tracker.md` is the regression suite for the
  Stimulus controllers — keep it current as surfaces are added.
- **Update `docs/tracker.md` at the end of every session.**
- Avoid vague summarisations like "The line between the two surfaces" or "Small, and mostly rearrangement."
- Always Write manageable volumes of texts that are useful to both humans and agents. No code > Less code > Lots of code. No comments (i.e. write the code well) > small comments > lots of descriptive comments. Don't write any comments that restate the code, labels an obvious purpose, narrates structure, or explains why something isn't there. Don't cite PRD or ADR section numbers in code.
- Always review and update the swagger API docs, if any changes are made to APIs. Edit the rswag specs in spec/requests/api/, keep response shapes in the shared components/schemas in spec/swagger_helper.rb (never hand-edit swagger/v1/swagger.yaml), then run `bundle exec rake rswag:specs:swaggerize` — every operation needs a description, request-body fields need per-field descriptions, and every response needs a schema $ref.
