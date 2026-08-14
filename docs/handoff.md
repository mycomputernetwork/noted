# notbuk — where things stand (14 Aug 2026, evening)

## Done
Milestones 1, 2 and 3 are **committed and pushed** (`f1ceb14`, `7db9a34`,
`54df03e`). The morning's handoff said milestone 3 was uncommitted; it isn't —
`54df03e` is it, and the working tree was clean before this session started.

Milestone 4 is **written to the working tree, uncommitted and unrun.** There
is no Ruby in the Cowork device VM and rubygems is blocked from the cloud
container, so nothing here has been executed — not the suite, not the browser.
Read this as a first pass that compiles in my head only.

## Pick up here (on the Mac)
```sh
cd ~/work/notbuk
mise exec -- bin/rails db:migrate      # adds notes.position; regenerates schema.rb
mise exec -- bin/rails test
mise exec -- bin/rails server
git add -A && git commit && git push
```
`db:migrate` first — the suite loads `db/schema.rb`, which does not have
`notes.position` in it yet, so every test fails until it runs.

Git still can't be driven through the Cowork device bridge (it leaves
`.git/*.lock` files it can't remove). To have Claude commit directly, start the
task from the desktop app's "Run this task" picker → run on your computer.

## What to click first
1. **The tree.** Folder triangles collapse and survive a reload. Open a note
   whose folder is collapsed — the folder should open anyway and close again
   when you leave.
2. **A sidebar note row → full pane.** Type, then click Back. The edit must be
   on the board. This is the milestone's actual test: the pane mounts
   `autosave_controller.js` unchanged.
3. **A card → still the modal.** Same note, same URL, different surface.
4. **Drag a card onto a folder.** Then drag one onto "Notes" to unfile it.
5. **Type a folder name at the foot of the list**, rename it (✎ on hover),
   delete it — its notes must survive as unfiled.

## Milestone 4 as built
- `Tree` (`app/models/tree.rb`) — two queries, grouped in Ruby, loaded in
  `ApplicationController` only for GET + HTML + not-a-frame. The guard
  matters: without it the tree would be built and thrown away on every
  autosave `PATCH`.
- **One URL, two surfaces.** `notes#show` renders the pane unless the request
  carries `Turbo-Frame: editor`, in which case it renders the modal as before.
  The frame header is already a record of where the click came from. PRD §7.7
  amended to say so.
- **The field partial needed one edit**: the close button is now optional,
  because the pane has nothing to close. Everything else in `notes/_fields` is
  untouched and `autosave_controller.js` is untouched, which is what §18 asked
  for.
- **Filing is a `PATCH` to the note**, not a folder operation — no new route.
  `filing_controller.js` sits on the shell because `dragstart` bubbles and the
  two ends of the drag are in opposite halves of it. Optimistic: the card dims
  on drop, and comes back with a red flash on the row if the save fails.
- Expansion state stores the **collapsed** set, so folders made later default
  to open without migrating what is stored.
- Folder CRUD lives in the tree. Create/rename/delete all redirect to a full
  page (`_top`), never into the row's frame — a rename moves the folder,
  changes every card's chip and every open editor's select, and none of that
  is inside that frame.
- The header nav is gone; the tree is the navigation now (§6). Below 52rem the
  rail is hidden outright.
- `notes.position` ships unused, per §18. The tree orders by it; nothing
  writes it until milestone 13.

## Watch for on first run
- **The autosave retry is still unexercised** — it was unexercised at the end
  of milestone 3 too. Backoff 1s → 30s, reset on success, immediate retry on
  `online`. To see it: open a note, stop the server, type, watch the status
  line count down, start the server again.
- **A flash of open tree on load.** The server renders every folder expanded
  and `tree_controller` collapses on connect. If it blinks, the fix is to
  render the collapsed state server-side, which means it stops being purely
  interface state — check it actually blinks before paying that.
- `dragleave` fires when the pointer crosses a child of a drop row, so the
  highlight may flicker. If it does, the fix is an enter/leave counter.
- The pane never runs `discardIfEmpty` — nothing can create an empty note
  there, since the note already exists. Emptying one out in the pane leaves an
  empty note, which is correct: discarding is for notes born on a keystroke.
- `docs/previews/*.html` predate milestone 3 and 4 both. The sidebar prototype
  is where this CSS came from and is now behind the real thing.

## Still open from before
- `User#time_zone` — nullable column now is free, and the calendar (6) leans
  on "today".
- Keyboard capture (`n` opens the composer). §17 says the fastest capture is a
  keystroke.
- The web app on a phone over Tailscale — the rail is hidden below 52rem,
  which makes this more pressing than it was.
- CSP / security headers, and verifying a backup *restores* → both fold into
  milestone 9.

## Asked and answered today
**Native clients (SwiftUI/macOS + Compose/Android).** Rough sizing, not a
decision: the server is close — milestone 3's endpoints already answer JSON,
so `/api/v1` is a namespace, a token endpoint and serializers for four flat
plain-text models, about one milestone. Each client is 4–8 weeks solo for
parity at today's scope, doubling if offline is real (Room / SwiftData +
sync) rather than a cache. Free on macOS: the tree
(`NavigationSplitView` + `OutlineGroup`) and filing (`.draggable` /
`.dropDestination`); masonry needs a custom `Layout`. Free on Android:
masonry (`LazyVerticalStaggeredGrid`); the tree doesn't. The autosave
controller is a real rewrite on both and the one worth porting carefully,
being the only part that can lose data. PRD §15's Turbo Native shell is days
rather than weeks and gives exact visual parity for free; offline is the only
thing a native client actually buys. **§15's decision — API or not — wants
making before the controllers are finalised, and everything so far leans
API.**

## Next
Milestone 5 (images) or 6 (calendar). 6 is the bigger half of the product and
the first caller for `Version`'s polymorphic table (§8.5); 5 is small and
makes the board look finished.

## Housekeeping
`_to_delete/` (gitignored) holds old smoke-test files, stale git locks and a
scratch tarball or two — safe to delete.
