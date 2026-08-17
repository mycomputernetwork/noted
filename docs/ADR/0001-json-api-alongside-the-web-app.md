# 0001 — A JSON API alongside the web app

**Status:** Accepted, 14 Aug 2026.

## Context

We want native clients — SwiftUI on macOS, Compose on Android — alongside the
web app. They need a JSON API. The web app does not: it renders HTML on the
server with Hotwire, and that works. So the server has to serve two kinds of
client without becoming two applications.

## Decision

**A JSON API beside the HTML surface, not beneath it.** Both are thin and sit on
the same models. Ownership scoping, validation and lifecycle rules live in the
models, so a JSON caller and an HTML caller cannot reach different outcomes; a
controller of either kind only chooses what to render.

**Reads are HTML, writes are JSON.** The browser is sent markup — board, tree,
note pane, calendar. Anything that changes a record goes through the API,
including from the browser, against the same endpoints the native clients use.
This is barely a change: saving is implicit, with no save button, so a browser
write was already a `fetch` returning JSON. Pointing it at the API gives notes
one write path instead of two.

The one exception, stated as a rule: **a write that is already a `fetch` uses the
API; a write that is a navigation stays a form.** Creating, renaming or deleting
a folder changes the tree, every card that mentions it, and every open editor's
folder control — a redirect repaints all of that for free. The API exposes
folder writes too (the clients need them); the browser just has a cheaper
correct option.

## Alternatives

- **Wrap the web views in a native shell.** Cheaper and visually exact, but a
  browser in a different frame — not a native client.
- **Have the browser render from JSON too.** One way in for everybody, at the
  cost of rebuilding the board, editor and tree client-side and reimplementing
  rules the server already enforces. The goal is one server that does not care
  who asked, not uniform clients.
- **A separate write path for the browser.** Two implementations of every write
  rule, their difference invisible until a second client finds it.

## Consequences

- One place a note can be written, so ownership and the discard rule can only be
  got wrong once.
- The browser exercises the API constantly, so it cannot quietly break between
  client releases.
- New rules belong in models. Two controller hierarchies exist and only the
  model is common — including the scoping helpers, which move to a shared concern
  rather than being written twice.
- The asymmetry is permanent and reads as an inconsistency before it reads as a
  rule: notes written over JSON, folders over forms.
- The browser now depends on a versioned API. It stays additive within a version;
  a breaking change ships everything together.
- The clients hold their own copy of the data, which makes sync a real question —
  see §6 below.

# Implementation

## 1. Reads are HTML, writes are JSON

The rule the rest of this depends on: anything the browser renders is composed
server-side; anything that changes a record goes through `/api/v1`, including
from the browser — except a write that is a *navigation* rather than a `fetch`,
which stays a form. Folder create, rename and delete are the only writes that
qualify today.

## 2. Refactors to the existing code

**Extract the scoping helpers.** `notes`, `folders`, `entries` and `logs` live
in `ApplicationController` today. They move to a `Scoped` concern that both base
controllers include, so `Api::V1::BaseController < ActionController::API`
inherits the isolation model rather than reimplementing it. This is the most
important line here: every query must originate from `current_user`, and a second
controller hierarchy is precisely where that quietly stops being true.

**`Api::V1::BaseController`.** `ActionController::API`, including `Scoped` and
`Authentication`, plus one `rescue_from ActiveRecord::RecordNotFound` → `404`.
Another account's id must miss, the same way it misses in HTML.

**Move the JSON out of `NotesController`.** `create`, `update` and `destroy`
become `Api::V1::NotesController`'s; `NotesController` is left rendering `new`,
`show` and `index` — HTML only. `autosave_controller.js` changes in one place:
its `createUrl` and `url` now point at `/api/v1/notes`. Its logic does not change
— the third time that file has survived a structural change untouched.

**Serializers are plain objects**, in `app/serializers` — not `as_json` overrides
and not a gem. Models are shared with the HTML surface and should not learn wire
formats; jbuilder is a template language for a job that is four hashes.

**One security consequence, landing with sign-in rather than now.**
`ActionController::API` does not verify authenticity tokens — right for a native
client with a bearer token, wrong for a browser with a session cookie, and the
browser is a caller. So authentication arrives as two paths into one `Session`
record: token for the clients, cookie plus CSRF for the web app. Worth knowing
while the endpoints are written, since it decides where the auth filter sits.
Today neither surface is protected on any path.

**No pagination yet.** At this scale — low thousands of notes — a full list is a
few hundred KB and the clients want all of it for offline anyway. When that stops
being true, the answer is a cursor on `(updated_at, id)` — the same index delta
sync needs (§5).

## 3. Representations

Plain text everywhere, ISO 8601 UTC for datetimes, `YYYY-MM-DD` for dates.
`user_id` is never serialised: a caller is one account by construction, and
sending an id nobody may use invites someone to filter by it.

**Note**
```json
{ "id": "3f2a0c5a-0d54-4749-9d4f-befdf745c253",
  "title": "Weeknight groceries", "body": "coffee beans\noat milk",
  "folder_id": "af96b8b4-5d79-4d2f-a801-5a66b96d40f7",
  "pinned": true, "position": null, "empty": false,
  "archived_at": null, "deleted_at": null,
  "created_at": "2026-08-14T09:12:00Z", "updated_at": "2026-08-14T18:40:12Z",
  "url": "/api/v1/notes/3f2a0c5a-0d54-4749-9d4f-befdf745c253",
  "html_url": "/notes/3f2a0c5a-0d54-4749-9d4f-befdf745c253",
  "images": [ { "id": "88", "url": "...", "byte_size": 41233, "filename": "x.jpg" } ] }
```

`empty` is computed and stays: the discard rule depends on a question only the
server can answer once images exist. `position` is exposed and null until
milestone 13 writes one; it orders the sidebar only, and a client that sorts a
board by it has misread the model.

**Folder**
```json
{ "id": "af96b8b4-5d79-4d2f-a801-5a66b96d40f7", "name": "Books",
  "position": 0,
  "created_at": "2026-08-14T09:12:00Z", "updated_at": "2026-08-14T18:40:12Z" }
```

The generated OpenAPI document is served through Rswag at `/api-docs`, and is
written to `swagger/v1/swagger.yaml` by `bin/rails rswag:specs:swaggerize`.

**DayEntry** keeps `start_minute` as an integer — it sorts correctly, renders
trivially on any client, and carries no timezone to misread. That choice was made
for exactly this moment.

**Day and Year are not serialised.** They are view-model objects that compose
rows for rendering; a JSON caller gets `day_entries` and `day_logs` for a date
range and composes its own. Serialising 365 mostly-empty days would ship the web
app's rendering strategy to clients that have their own.

**Errors** are `{ "errors": ["Name already exists"] }` with `422`. `404` for
anything belonging to another account, never `403` — a caller learning an id
exists is the leak.

## 4. Endpoints by milestone

Every milestone from 5 ships its JSON with its HTML. Notes and folders owe a
catch-up slice because they predate the decision.

**Milestone 16, the catch-up — notes and folders.** First, before any further
feature work, because a client is being built against it in parallel.
```
GET    /api/v1/notes            list (kept, or ?scope=archived|trashed later)
GET    /api/v1/notes/:id
POST   /api/v1/notes            create-on-first-keystroke
PATCH  /api/v1/notes/:id
DELETE /api/v1/notes/:id        discard — refuses a note with content in it
GET    /api/v1/folders
POST   /api/v1/folders
PATCH  /api/v1/folders/:id
DELETE /api/v1/folders/:id      unfiles its notes, never deletes them
```
Filing is `PATCH /notes/:id` with a `folder_id`, as the web app's drag-to-file
already does. It gets no endpoint of its own: it is a note with a different
folder, not an operation.

**Milestone 5 — images.** Uploads go through Active Storage's direct upload
endpoint; the API accepts `image_signed_ids` on create and update and returns
ordered image descriptors. Blob URLs expire after an hour
(`config/initializers/active_storage.rb`), so a native client must **download and
cache the bytes**, never persist the URL — an offline gallery of expired links
shows up a week after release.

**Milestone 6 — calendar.**
```
GET    /api/v1/day_entries?from=2026-01-01&to=2026-12-31
POST   /api/v1/day_entries      kind, date, body, start_minute
PATCH  /api/v1/day_entries/:id  including completed_at for check-off
DELETE /api/v1/day_entries/:id
GET    /api/v1/day_logs?from=&to=
PUT    /api/v1/day_logs/:date   upsert — one log per day is the constraint
```
Rollover is a read, not a write: `carried_into` is a query the client makes for
itself, or a `?carried=true` flag on the range request. No job re-dates anything,
on either surface.

**Milestone 8 — search, archive, trash.** `GET /api/v1/search?q=` returning hits
grouped by type, over FTS5. Clients will want local search over their own cache
eventually; the server endpoint still serves the first run before a cache exists.

**Milestones 13 and 14 — ordering and versions.** `PATCH /api/v1/notes/reorder`
takes an ordered id list, written in one transaction scoped through
`current_user`. Versions are read-only: `GET /api/v1/notes/:id/versions`. No
restore on any surface.

## 5. Schema to add now: `deleted_at`, `updated_at` index

Both are free now, a migration against live rows later.

**`deleted_at` on `Folder` and `DayLog`.** `Note` and `DayEntry` already have it.
An offline client cannot tell "this folder was deleted" from "never sent to me"
unless deletion leaves a tombstone; without it, the first sync after a delete
either resurrects the folder or drops something else. Add it with milestone 6 at
the latest.

**An index on `updated_at` per synced table.** Delta sync is
`WHERE updated_at > ?`, the only query in the app not already scoped by an indexed
column.

Neither needs behaviour now; both stop being free the moment a client holds rows.

## 6. Sync design

Nothing before milestone 10 forces this, but two decisions constrain the schema,
so they belong here.

**Delta by `updated_at`, tombstones by `deleted_at`.** One endpoint,
`GET /api/v1/changes?since=`, returning changed and deleted rows per type. This is
why §5 matters.

**Last write wins, per record — and `Version` makes it survivable.**
Last-write-wins was accepted about two browsers on one tailnet, not a phone
offline for a day. The honest version: a losing write must not vanish. When the
server rejects an update as stale, the incoming body becomes a **version**
(milestone 14) rather than nothing — turning "I lost an afternoon" into "the
afternoon is in the history slider," which is the whole reason version history
exists.

Per-field merge is tempting and wrong: the field people conflict over is `body`,
and merging two plain-text bodies is either a diff3 or a lie.

**Open — ids for records created offline.** Either the client generates a UUID
carried alongside the server id, or it keeps an outbox with temporary local ids
rewritten on acknowledgement. The outbox is simpler and needs no schema change;
the UUID is more robust and needs a column on every table. Not worth deciding
until a client actually writes offline — but it is a schema question, so not free.

## 7. Milestone 16: done criteria

The catch-up goes first — an Android client starts against it immediately, so it
is the one piece of work with a consumer waiting:

1. `Scoped` concern extracted; `ApplicationController` and
   `Api::V1::BaseController` both include it.
2. `Api::V1::NotesController` and `Api::V1::FoldersController`, with serializers.
3. `autosave_controller.js` repointed; JSON removed from `NotesController`.
4. Integration tests per endpoint, and — the one that matters — isolation
   asserted against the API the way `test/models/isolation_test.rb` asserts it
   against the models: every path missing on another account's id, including the
   ones reached by `folder_id` in a body.
5. The wire format written down (§3) as it is built. It is the contract a second
   developer works from the same week; a field renamed after the client parses it
   is not a refactor.

The suite stays server-side. No system tests, no browser drivers.

## 8. Out of scope

- **The browser does not render from JSON.** Board, tree and pane stay
  server-rendered. One server that does not care who asked — not three clients
  built the same way.
- **No versioning before there are two callers.** `/api/v1` is a path segment and
  a promise to stay additive within it, not a compatibility layer.
- **No client abstraction.** Compose and SwiftUI want different local storage
  (Room, SwiftData/GRDB) and concurrency models. The shared artefact between them
  is this document and the token format, not code.
