# Architecture decision records

One file per decision, numbered in order, never renumbered. A record is
written when the reasoning would otherwise survive only as the shape of the
code. Records are superseded, never edited to change their decision.

Earlier decisions — notes and the calendar as separate objects, plain text
with no markup, read-only history with no restore — live in `docs/PRD.md`,
which is written as argument rather than specification.

| # | Decision | Status |
|---|---|---|
| [0001](0001-json-api-alongside-the-web-app.md) | A JSON API alongside the web app | Accepted |
| [0002](0002-offline-sync-and-client-identity.md) | Offline sync and client identity | Accepted (refines 0001 §5–§6) |
| [0003](0003-centralized-auth-service.md) | A centralized auth service, federated over OIDC | Accepted |
