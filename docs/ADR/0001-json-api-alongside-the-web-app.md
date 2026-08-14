# 0001 — A JSON API alongside the web app

**Status:** Accepted, 14 Aug 2026.
**Plan:** `docs/api-plan.md`.

## Context

We want native clients — SwiftUI on macOS, Compose on Android — alongside the
web app. They need a JSON API. The web app does not: it renders HTML on the
server with Hotwire, and that works well.

So the server has to serve two kinds of client without becoming two
applications.

## Decision

**A JSON API beside the HTML surface, not beneath it.** Both are thin, and
both sit on the same models. Ownership scoping, validation and lifecycle rules
live in models, so a JSON caller and an HTML caller cannot reach different
outcomes. A controller of either kind chooses what to render and nothing else.

**Reads are HTML, writes are JSON.** The browser is sent markup — board, tree,
note pane, calendar. Anything that changes a record goes through the API,
including from the browser, against the same endpoints the native clients use.

This is less of a departure than it sounds: saving here is implicit, with no
save button anywhere, so a write in the browser was never a form submission —
it is a `fetch` that gets JSON back, and has been since the editor was built.
Pointing it at the API means notes have one write path instead of two.

The exception, stated as a rule: **a write that is already a `fetch` uses the
API; a write that is a navigation stays a form.** Creating, renaming or
deleting a folder changes the tree, every card that mentions it, and every
open editor's folder control — a redirect repaints all of that for free. The
API exposes folder writes too, because the clients need them; the browser just
has a cheaper correct option.

## Alternatives

- **Wrap the web views in a native shell.** Much cheaper and visually exact,
  but it is a browser in a different frame — not a native client.
- **Have the browser render from JSON too.** One way in for everybody, at the
  cost of rebuilding the board, editor and tree client-side and reimplementing
  rules the server already enforces. Uniformity between clients is not the
  goal; one server that does not care who asked is.
- **A separate write path for the browser.** Two implementations of every
  write rule, and the difference between them invisible until a second client
  goes looking.

## Consequences

- One place a note can be written, so ownership and the discard rule can only
  be got wrong once.
- The browser exercises the API constantly, so it cannot quietly break between
  client releases.
- New rules belong in models. Two controller hierarchies exist and only the
  model is common to both — including the scoping helpers, which move to a
  shared concern rather than being written twice.
- The asymmetry is permanent and reads as an inconsistency before it reads as
  a rule: notes are written over JSON, folders over forms.
- The browser now depends on a versioned API. It stays additive within a
  version, and a breaking change ships everything together.
- The clients hold their own copy of the data, which makes sync a real
  question — see `docs/api-plan.md`.
