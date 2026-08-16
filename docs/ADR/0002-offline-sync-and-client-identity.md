# 0002 — Offline sync and client identity

**Status:** Accepted, 15 Aug 2026. Refines ADR 0001 §5–§6.

## Context

Milestone 10 puts a Compose client on a phone that will be edited offline. ADR
0001 §6 left sync open and leaned toward making a losing write survivable by
turning it into a `Version`. Building the clients forces the question, and two
parts of the answer are schema-shaped — primary keys and a soft-delete policy —
so they are cheaper to settle before any client holds data than after.

## Decision

**Last write wins, per record, and a stale write is accepted.** When two edits
race, the last to reach the server wins and the other is overwritten. No
conflict detection, no per-field merge, no precondition token. This is the honest
model for noted: one person across a handful of their own devices, not a shared
document. A collaborative editor would need more; this is not one.

**Version history is not the safety net for overwrites.** ADR 0001 §6 proposed
routing a losing write into a `Version`. Dropped. Versions (milestone 14) are a
time-bucketed snapshot taken on save — a new version when the last one is more
than ten minutes old — and are independent of sync. They exist so a person can
walk back their *own* edits, not to reconcile devices. A sync overwrite between
two snapshots is not recoverable, and that is the accepted cost of a simple model.

**Every table has a client-generatable UUID primary key.** Primary keys are
string UUIDs across the whole schema. A client creates a record offline with its
own UUID and queues it; the server keeps that id unchanged. There is no outbox
that rewrites temporary ids on acknowledgement, and no id that means one thing on
the client and another on the server — a note filed offline into a folder made
offline already holds that folder's real id. `config.generators
primary_key_type: :string` carries this into the Active Storage tables; the app's
own migrations pass `id: :string` and `type: :string` explicitly.

**Folder names are not unique.** A folder is identified by its id, not its name,
so two folders may share a name — within an account or across accounts. The
former unique index existed to dedupe by name; identity by id makes it wrong, not
just unnecessary, because two offline clients naming a folder the same thing must
both sync.

**No timed trash purge.** Trash is retained until it is manually emptied. The
30-day `PurgeTrashedNotesJob` is removed. A tombstone that a slow client has not
yet seen cannot be collected out from under it on a timer, and at this scale
(PRD §4) unbounded trash is cheaper to reason about than a retention window.

## Consequences

- Delta sync stays what ADR 0001 §5 described: `WHERE updated_at > ?` plus
  `deleted_at` tombstones. Those additions — `deleted_at` on `folders` and
  `day_logs`, an `updated_at` index per synced table — are **still wanted and
  still not built**; they land with the sync engine at milestone 10, not now.
  Folder deletion is a hard delete until then.
- A losing write is gone, not archived. Accepted deliberately; version-on-save
  catches most "I lost an afternoon" cases, but not an overwrite that lands
  between two snapshots.
- An id is no longer a proxy for creation order. Ordering must name its column
  (`updated_at`, `created_at`, `position`), which the models already do; only a
  test that reached for `order(:id).last` to mean "newest" had to change.
- `day_entries` and `day_logs` get UUIDs in this change, so the calendar API
  (milestone 6) inherits the identity decision rather than reopening it.

## Out of scope

- **The `/api/v1/changes?since=` endpoint and the client sync engine.** This
  record decides the model and the schema it needs; the endpoint is milestone 10.
- **A token precondition on writes.** Deliberately not added — last write wins
  means there is nothing for the server to reject.
