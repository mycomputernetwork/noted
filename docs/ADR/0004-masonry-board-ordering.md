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
The All Notes board and each folder board answer different questions. A note can
therefore be first in a folder's sidebar branch without being first on that
folder's board, and first inside that folder without moving on All Notes.

## Decision

Add `notes.board_position` for All Notes and `notes.folder_board_position` for a
note's current folder board. Keep `notes.position` for the sidebar tree. Boards
order pinned notes first, then unpinned notes. All Notes uses `board_position`
within each zone; a folder board uses `folder_board_position`, falling back to
`board_position` and then edited order.

New notes get a `board_position` before the current first note. Notes created in
or moved into a folder also get a `folder_board_position` before that folder's
current first note.

Reordering is one API write: `PATCH /api/v1/notes/reorder` with every visible
note id in the board's new order, plus `folder_id` when the open board is a
folder. The server scopes the operation through `current_user`, rejects missing
or foreign ids, and rewrites only the chosen board's order column.

Pinned and unpinned notes are separate drag zones. Dragging does not pin or
unpin; the editor's pin control remains the only way to move a note across that
boundary.

## Consequences

- The sort UI is removed. Recency is still visible as card metadata, not an
  ordering mode.
- Board reorder and sidebar reorder can evolve independently.
- Android stores `boardPosition` and `folderBoardPosition` locally and pushes
  them with note updates, so offline reorders fit the existing dirty-row sync
  path.
- The web keeps one drag source for two outcomes: a board card dropped on a
  card reorders the board, and the same card dropped on a sidebar folder files
  it.
