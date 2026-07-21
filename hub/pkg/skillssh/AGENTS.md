# skills.sh Synchronization Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `client.go`: calls the stateless Vercel bridge and decodes bounded leaderboard page batches.
- `client_test.go`: verifies the exact protected endpoint, request parameters, and decoded page contract.
- `worker.go`: schedules all-time crawls, acquires and renews fenced database leases, and publishes only complete snapshots.
- `worker_test.go`: verifies multi-instance exclusion, lease-loss cancellation, pagination, and complete-crawl publication.

## Architectural Boundary

This module owns external skills.sh synchronization orchestration. It delegates
durable leases, fencing, crawl snapshots, and observations to Catalog. It must
not calculate public leaderboard rankings, expose HTTP routes, or treat counter
observations as authoritative install events.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
