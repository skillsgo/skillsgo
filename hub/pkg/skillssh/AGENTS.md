# skills.sh Synchronization Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `client.go`: calls the stateless Vercel bridge and decodes bounded leaderboard page batches.
- `client_test.go`: verifies the exact protected endpoint, request parameters, and decoded page contract.
- `worker.go`: executes one River-scheduled all-time crawl under a Catalog-issued crawl-generation fence and publishes only complete snapshots.
- `worker_test.go`: verifies completed-window idempotency, retry propagation, stale-generation rejection, pagination, and complete-crawl publication.

## Architectural Boundary

This module owns external skills.sh synchronization orchestration. It delegates
generation fencing, crawl snapshots, and observations to Catalog. It must
not calculate public leaderboard rankings, expose HTTP routes, or treat counter
observations as authoritative install events.

Periodic scheduling, execution ownership, and retry belong to `pkg/taskqueue` and River. Catalog's per-crawl generation token remains the domain-level stale-writer guard for River's at-least-once recovery model; it is not a second scheduler or lease system.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
