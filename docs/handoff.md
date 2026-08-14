# notbuk — where things stand (14 Aug 2026)

## Done
Milestones 1 and 2 are **committed and pushed** (`7db9a34`, `f1ceb14`).

Milestone 3 is **written to the working tree, uncommitted.** The first pass
passed the suite on the Mac. Three things landed on top of it that have **not**
been run: the in-place composer, the pin rework, and the autosave retry.

## Pick up here (tomorrow, on the Mac)
```sh
cd ~/work/notbuk
mise exec -- bin/rails test
mise exec -- bin/rails server   # click "Take a note", type, click away
git add -A && git commit && git push
```
Git still can't be driven through the Cowork device bridge — it leaves
`.git/*.lock` files it can't remove. To have Claude commit directly, start the
task from the desktop app's "Run this task" picker → run on your computer.

Then: milestone 4 (sidebar tree, full-pane note, drag-to-file). Build the pane
as a third wrapper around `notes/_fields`, mounting `autosave` and no frame
controller at all. If that partial needs an edit to work there, the milestone 3
split was wrong.

## Milestone 3 as built
- `autosave_controller.js` — form + create URL + update URL, nothing else.
  800ms debounce, immediate on blur/change, requests chained (never parallel),
  flush on unload and `turbo:before-visit` with `keepalive`. Milestone 4's
  full-pane note must mount it **unchanged**.
- **A failed save retries itself** — backoff doubling 1s → 30s, reset on
  success, immediate retry on the `online` event. It previously said
  "retrying" and then waited for the next keystroke, which was a lie in the
  exact case (tailnet dropped) the message existed for.
- `notes/_fields` is the editor, surface-independent. `_editor` wraps it in a
  `<dialog>`, `new.html.erb` wraps it in the composer. The full pane is the
  third wrapper — that's the whole of §8.4.
- **The composer expands in place, not into a dialog** (new §8.2a). A modal
  keeps something visible behind it and a new note has nothing behind it; a
  scrim would also put the note somewhere other than where it will live.
  Click-outside / Escape / Done are one act. On close the board refreshes and
  the card the note landed in is highlighted, focused and scrolled to; if
  nothing was typed the composer collapses and the board is untouched.
- Board refreshes **on close, not on save** — a Turbo same-URL visit, morphed
  (`turbo-refresh-method: morph` in the layout). Patching the card in place
  would leave the board sorted wrongly, since editing is what moves a note to
  the front under "last edited". Triggered by `autosave:finalized`, so it
  can't render pre-save state.
- Pin is a corner control in the editor with a drawn thumbtack
  (`notes/_pin_icon`, 21px, inset `--space-2`). **Cards carry no pin badge** —
  the Pinned section already says it.
- Endpoints answer **JSON, not Turbo Streams** — they're called by fetch, and
  what the client needs back is where to send the next save.
- `DELETE /notes/:id` is **discard**: refuses anything that isn't
  `Note#empty?`. Trashing a real note is milestone 8, via `deleted_at`.
- Cards are `<article>`s wrapping a full-cover link — milestone 4 makes the
  card a drag source and a draggable link drags its href.

## Watch for on first run
- Selection after the composer closes rides on a one-shot `turbo:render`
  listener parked on the window. If the highlight never appears, that event
  under morphing is the thing to check.
- `focusout` on the composer fires while the click that closes it is still
  travelling.
- A failed **create** that actually succeeded server-side would be retried as
  a second POST. Accepted for a personal app; noted in case duplicates ever
  show up.

## Decided today, built later
**Milestone 14 — version history** (new PRD §8.5 and a `Version` row in §5).
Read-only: look and copy, never restore. A restore button is a merge question
and a second place a note can be edited from.
- **Polymorphic `versions` table from the start** (`record_type`/`record_id`).
  This was the only part that could not wait: milestone 6's "did today" log is
  a second caller, and notes-only stops being a free choice the moment there
  are rows in it. Everything else about the feature is additive.
- **One version per editing session** — snapshot the previous body on save,
  but only if the newest version is more than ten minutes old. A gap, not a
  window: an afternoon in one sitting is one version, picking the note up
  after dinner is a second.
- **Keep everything.** Session coalescing is what makes that affordable.
- Text only, never images. Not indexed by search (milestone 8) — surfacing
  text you deleted a year ago as a hit is a bug. Purging a trashed note takes
  its versions with it. The Keep import creates none (12).
- UI lives in the shared field partial, so all three surfaces inherit it.

## Also raised, not yet decided
- `User#time_zone`. The calendar (6) leans on "today" — rollover, the anchored
  row — and that is currently the server's zone. Same argument as shipping
  `user_id` before auth: a nullable column now is free.
- Keyboard capture (`n` to open the composer). §17 says capture friction is
  the thing to optimise and the fastest capture is a keystroke.
- The web app on a phone. Android is milestone 10, but over Tailscale the
  phone browser is the first mobile client and nothing covers it.
- CSP / security headers → fold into milestone 9. Verifying a backup *restores*
  → same.

## Type scale (settled, don't re-scale uniformly)
Sized by role, not one multiplier: body 17px (the base), title 21, chrome 14,
metadata 12.5, section labels 11. Card min-width 17rem ≈ 45-character measure.
Root font-size is left alone on purpose.

## PRD — `docs/PRD.md`, v7
- §7.6 sidebar tree; §7.7 full-pane note; §8.2a composer in place; §8.5 version
  history; §8.4 three surfaces, one save path: **card → modal, composer → in
  place, sidebar row → full pane**. The rule is where you clicked, never how
  long the note is.
- `position` on Note orders the **sidebar only**; the board stays edited/created.
- Milestone 4 = sidebar tree + full-pane note + drag-to-file.
  13 = manual drag ordering. 14 = version history.

## Previews
`docs/previews/board.html` and `docs/previews/sidebar-prototype.html` inline a
snapshot of the stylesheet, so they drift — they do **not** include the
milestone 3 editor, composer or pin styles.

## Housekeeping
`_to_delete/` (gitignored) holds old smoke-test files, stale git locks and a
scratch tarball — safe to delete.