# Previews

Static HTML, opened directly in a browser — no Rails, no server.

| File | What it is |
|---|---|
| `board.html` | The milestone 2 board as built: real stylesheet, real masonry algorithm, seed-shaped notes. |
| `sidebar-prototype.html` | Milestone 4's sidebar tree (PRD §7.6), mocked. Clickable: a folder name filters the board, the triangle expands, a card opens the modal, a sidebar row opens the note full-pane. |

Both inline a copy of `app/assets/stylesheets/application.css` taken when they
were generated, so they drift as the real stylesheet changes. They are design
artefacts for review, not a test surface — nothing in the app loads them.

`sidebar-prototype.html` mocks components that do not exist in the app yet;
the CSS in its second `<style>` block is where milestone 4 starts.
