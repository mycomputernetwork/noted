# notbuk — the API plan

**Status:** accepted, 14 Aug 2026. How to build what
[ADR 0001](ADR/0001-json-api-alongside-the-web-app.md) decided — the reasoning
is there, the endpoints and the order of work are here.
**Decided already:** native Compose (Android) and SwiftUI (macOS) clients
against a parallel `/api/v1`; the web app goes on rendering HTML with Hotwire.
**Out of scope here:** authentication and token issuance. Those are milestone
7's, and this plan assumes `current_user` keeps working the way it does today.

---

## 1. The line between the two surfaces

Decided in ADR 0001, repeated here because everything below depends on it:

> **Reads are HTML. Writes are JSON.** Anything the browser renders is
> composed server-side. Anything that changes a record goes through
> `/api/v1`, including from the browser — with the exception that a write
> which is a *navigation* rather than a `fetch` stays a form. Folder create,
> rename and delete are the only writes that qualify today.

## 2. What has to change in what is already built

Small, and mostly rearrangement.

**Extract the scoping helpers.** `notes`, `folders`, `entries` and `logs` live
in `ApplicationController` today. They move to a `Scoped` concern that both
base controllers include, so `Api::V1::BaseController < ActionController::API`
inherits the isolation model rather than reimplementing it. This is the single
most important line of the plan: §5 says every query originates from
`current_user`, and a second controller hierarchy is precisely where that
would quietly stop being true.

**`Api::V1::BaseController`.** `ActionController::API`, including `Scoped` and
`Authentication`, plus one `rescue_from ActiveRecord::RecordNotFound` →
`404`. Another account's id must miss, and it must miss the same way it misses
in HTML.

**Move the JSON out of `NotesController`.** `create`, `update` and `destroy`
become `Api::V1::NotesController`'s; `NotesController` is left rendering
`new`, `show` and `index` — HTML only, which is what a Hotwire controller
should be. `autosave_controller.js` changes in one place: its `createUrl` and
`url` values now point at `/api/v1/notes`. The controller's logic does not
change at all, which is the third time that file has survived a structural
change untouched.

**Serializers are plain objects**, in `app/serializers`, not `as_json`
overrides and not a gem. Models are shared with the HTML surface and should
not learn about wire formats; jbuilder is a template language for a job that
is four hashes.

**One security consequence, which lands with sign-in rather than now.**
`ActionController::API` does not verify authenticity tokens. That is right for
a native client presenting a bearer token and wrong for a browser presenting a
session cookie — and the browser is a caller. So authentication has to arrive
as two paths into one `Session` record: token for the clients, cookie plus
CSRF verification for the web app. Worth knowing while the endpoints are being
written, since it decides where the authentication filter sits rather than
what it does. Today neither surface is protected on any path.

**No pagination yet.** At §4's scale — low thousands of notes — a full list is
a few hundred KB and the clients want all of it anyway for offline. The moment
that stops being true, the answer is a cursor on `(updated_at, id)`, which is
the same index delta sync needs (§5 of this document).

---

## 3. Representations

Plain text everywhere, ISO 8601 UTC for datetimes, `YYYY-MM-DD` for dates.
`user_id` is never serialised: a caller is one account by construction, and
sending an id nobody may use invites someone to try filtering by it.

**Note**
```json
{ "id": 12, "title": "Weeknight groceries", "body": "coffee beans\noat milk",
  "folder_id": 3, "pinned": true, "position": null, "empty": false,
  "archived_at": null, "deleted_at": null,
  "created_at": "2026-08-14T09:12:00Z", "updated_at": "2026-08-14T18:40:12Z",
  "images": [ { "id": 88, "url": "...", "byte_size": 41233, "filename": "x.jpg" } ] }
```

`empty` is computed and stays, because the discard rule (§8.1) depends on a
question only the server can answer once images exist. `position` is exposed
and null until milestone 13 writes one; it orders the sidebar only, and a
client that sorts a board by it has misread §5.

**DayEntry** keeps `start_minute` as an integer, which is why §5 chose it over
a `time` column in the first place: it sorts correctly, renders trivially on
any client, and carries no timezone to misinterpret. That decision was made
for this moment and it is worth noticing that it paid.

**Day and Year are not serialised.** They are view-model objects that compose
rows for rendering; a JSON caller gets `day_entries` and `day_logs` for a date
range and composes its own. Serialising 365 mostly-empty days would ship the
web app's rendering strategy to clients that have their own.

**Errors** are `{ "errors": ["Name already exists"] }` with `422`, which is
what the note endpoints already answer. `404` for anything belonging to
another account, never `403` — a caller learning that an id exists is the
leak.

---

## 4. Endpoints, by the milestone that ships them

Every milestone from 5 ships its JSON with its HTML (PRD §15). Notes and
folders owe a catch-up slice because they predate the decision.

**Milestone 16, the catch-up — notes and folders.** First, and before any
further feature work, because a client is being built against it in parallel.
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
Filing is `PATCH /notes/:id` with a `folder_id`, exactly as the web app's
drag-to-file already does it. It does not get an endpoint of its own, because
it is not an operation — it is a note with a different folder.

**Milestone 5 — images.** Uploads go through Active Storage's existing direct
upload endpoint; the API accepts `image_signed_ids` on create and update and
returns ordered image descriptors. One caveat with teeth: blob URLs expire
after an hour (`config/initializers/active_storage.rb`), so a native client
must **download and cache the bytes**, never persist the URL. An offline
gallery of expired links is the kind of bug that shows up a week after
release.

**Milestone 6 — calendar.**
```
GET    /api/v1/day_entries?from=2026-01-01&to=2026-12-31
POST   /api/v1/day_entries      kind, date, body, start_minute
PATCH  /api/v1/day_entries/:id  including completed_at for check-off
DELETE /api/v1/day_entries/:id
GET    /api/v1/day_logs?from=&to=
PUT    /api/v1/day_logs/:date   upsert — one log per day is the constraint
```
The rollover (§5) is a read, not a write, and stays that way: `carried_into`
is a query the client can make for itself, or a `?carried=true` flag on the
range request. What must not happen is a job that re-dates anything, on either
surface.

**Milestone 8 — search, archive, trash.** `GET /api/v1/search?q=` returning
hits grouped by type, over FTS5. Native clients will eventually want local
search over their own cache; the server endpoint is still worth having for the
first run before a cache exists.

**Milestones 13 and 14 — ordering and versions.** `PATCH
/api/v1/notes/reorder` taking an ordered id list, written in one transaction
scoped through `current_user`. Versions are read-only over the API too:
`GET /api/v1/notes/:id/versions`. There is no restore on any surface (§8.5).

---

## 5. Two columns to add before they are expensive

Both are the same argument as `user_id` in milestone 1 and the polymorphic
`versions` table in 14: free now, a migration against live rows later.

**`deleted_at` on `Folder` and `DayLog`.** `Note` and `DayEntry` already have
it. An offline client cannot distinguish "this folder was deleted" from "this
folder was never sent to me" unless deletion leaves a tombstone. Without it,
the first sync after a folder is deleted either resurrects it or silently
drops something else. Add it with milestone 6 at the latest.

**An index on `updated_at` per synced table.** Delta sync is
`WHERE updated_at > ?`, and it is the only query in the application that is
not scoped by something already indexed.

Neither needs any behaviour now. Both stop being free the moment a client is
holding rows.

---

## 6. Sync — the shape, not the implementation

Nothing before milestone 10 forces this, but two decisions constrain the
schema, so they belong here rather than in the client.

**Delta by `updated_at`, tombstones by `deleted_at`.** One endpoint,
`GET /api/v1/changes?since=`, returning changed and deleted rows per type.
This is why §5 of this document matters.

**Last write wins, per record — and `Version` is what makes that survivable.**
§3 already accepts last-write-wins, but it accepted it about two browsers on
the same tailnet, not about a phone that has been in a pocket for a day. The
honest version for a real offline client is that a losing write must not
vanish: when the server rejects an update as stale, the incoming body becomes
a **version** (milestone 14) rather than nothing. That turns the worst case
from "I lost an afternoon's edits" into "the afternoon is in the history
slider" — which is the entire reason version history exists, arriving in a
place nobody planned it for.

Per-field merge is tempting and wrong here: the field people conflict over is
`body`, and merging two versions of a plain-text body is either a diff3 or a
lie.

**Open: ids for records created offline.** Either the client generates a UUID
carried alongside the server id, or it keeps an outbox with temporary local
ids and rewrites them on acknowledgement. The outbox is simpler and needs no
schema change; the UUID is more robust and needs a column on every table. Not
worth deciding until the first client actually writes offline, but worth
knowing it is a schema question and therefore not free.

---

## 7. What "done" looks like for the catch-up slice

This is milestone 16, and it goes first — an Android client starts against it
immediately, so it is the one piece of work with a consumer waiting:

1. `Scoped` concern extracted; `ApplicationController` and
   `Api::V1::BaseController` both include it.
2. `Api::V1::NotesController` and `Api::V1::FoldersController`, with
   serializers.
3. `autosave_controller.js` values repointed; JSON removed from
   `NotesController`.
4. Integration tests per endpoint, and — the one that matters — the isolation
   property asserted against the API the way `test/models/isolation_test.rb`
   asserts it against the models. Every API path must miss on another
   account's id, including the ones reached by `folder_id` in a body.
5. The wire format written down as it is built, in §3 of this document. It is
   the contract a second developer is working from the same week; a field
   renamed after the client has parsed it is not a refactor.

The suite stays server-side. No system tests, no browser drivers.

## 8. What this plan deliberately does not do

- **It does not make the browser render from JSON.** The board, the tree and
  the pane stay server-rendered. Three clients does not mean three clients
  built the same way; it means one server that does not care which asked.
- **It does not version anything before it has two callers.** `/api/v1` is a
  path segment and a promise to be additive within it, not a compatibility
  layer.
- **It does not build a client abstraction.** Compose and SwiftUI will want
  different local storage (Room, SwiftData/GRDB) and different concurrency
  models. The shared artefact between them is this document and the token
  format, not code.
