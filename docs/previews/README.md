# Previews

Static HTML, opened directly in a browser — no Rails, no server.

| File | What it is |
|---|---|
| `board.html` | The milestone 2 board as built: real stylesheet, real masonry algorithm, seed-shaped notes. |
| `sidebar-prototype.html` | Milestone 4's sidebar tree (PRD §7.6), mocked. Clickable: a folder name filters the board, the triangle expands, a card opens the modal, a sidebar row opens the note full-pane. |

Both inline a copy of `app/assets/stylesheets/application.css` taken when they
were generated, so they drift as the real stylesheet changes. They are design
artefacts for review, not a test surface — nothing in the app loads them.

**Both are now behind the application.** `board.html` predates the milestone 3
editor, composer and pin styles. `sidebar-prototype.html` did its job — its
tree CSS is where milestone 4's rail came from — and the built version has
since moved past it: a drawn caret rotated by `aria-expanded` rather than
swapped glyphs, a rename control on the folder row, drop-target states for
filing, and no pin badge on cards.

Kept anyway, and not refreshed. They are dated design artefacts — what was
being aimed at, at the moment it was being aimed at — and a preview quietly
regenerated to match the app is a screenshot, which the app already provides
by being run. Anything new gets a new file.
