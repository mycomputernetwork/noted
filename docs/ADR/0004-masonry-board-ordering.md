# 0004 — Masonry board ordering

**Status:** Accepted, 1 Sep 2026.

## Context

The board originally sorted by edited or created time, while `notes.position`
ordered only the sidebar tree. The new board requirement is manual masonry
ordering on web and Android: drag a card, let the grid make room, and keep that
place after drop. Cards can also still be dragged onto folders in the web
sidebar.

Reusing `position` would couple two different lists. The tree order is
folder-local, because unfiled notes and each folder branch are separate shelves.
The board order is one sequence across the board, filtered by folder when a
folder board is open. A note can therefore be first in a folder's sidebar branch
without being first on that folder's board.

## Decision

Add `notes.board_position` for the masonry board. Keep `notes.position` for the
sidebar tree. The board orders pinned notes first, then unpinned notes, and uses
`board_position` within each zone. Null `board_position` falls back to edited
order, so existing rows need no data migration; the first board reorder writes
the submitted visible sequence.

New notes get a `board_position` before the current first note, so capture still
lands at the front without shifting every existing row.

Reordering is one API write: `PATCH /api/v1/notes/reorder` with every visible
note id in the board's new order, plus `folder_id` when the open board is a
folder. The server scopes the operation through `current_user`, rejects missing
or foreign ids, and rewrites positions in the global board sequence while
leaving non-visible notes in place.

Pinned and unpinned notes are separate drag zones. Dragging does not pin or
unpin; the editor's pin control remains the only way to move a note across that
boundary.

## Consequences

- The sort UI is removed. Recency is still visible as card metadata, not an
  ordering mode.
- Board reorder and sidebar reorder can evolve independently.
- Android stores `boardPosition` locally and pushes it with note updates, so
  offline reorders fit the existing dirty-row sync path.
- The web keeps one drag source for two outcomes: a board card dropped on a
  card reorders the board, and the same card dropped on a sidebar folder files
  it.
