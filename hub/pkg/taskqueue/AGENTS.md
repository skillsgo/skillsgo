# Hub Task Queue Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `runtime.go`: defines type-safe River job/finalizer registration, bounded source/default/maintenance worker allocation with four-way default translation capacity at the production budget, exact active-job lookup for domain reconciliation, sleep-first periodic submission, burst startup/idle shutdown, future-job wake scheduling, configurable failure detection, and PostgreSQL execution without a generic envelope.
- `runtime_test.go`: verifies typed synchronous dispatch, terminal finalization, periodic cancellation, registration freezing, unknown job rejection, wake coalescing, and due-versus-future work decisions.
- `postgres_integration_test.go`: verifies River schema migration, burst startup/idle shutdown/restart, process-local periodic submission, scheduled wakeup, transactional commit/rollback behavior, transient-failure retry, `MaxAttempts` exhaustion into `discarded`, cross-client uniqueness, durable submission, and execution against opt-in real PostgreSQL.
- `crash_recovery_integration_test.go`: force-kills a subprocess during handler execution and verifies a replacement River process rescues and re-executes the durable running job.

## Architectural Boundary

This module owns durable asynchronous task transport and local synchronous substitution. It must not own Hub domain decisions, persist business state outside River tables, or make handlers non-idempotent.

Business handlers are registered during service assembly and frozen by `Start`. Use `Runtime.Every` for recurring work instead of package-owned tickers. Its process-local timers wait without touching PostgreSQL, submit durable River jobs when due, and wake burst workers. Description translation, Repository source-metadata refresh, and Repository History Backfill remain routed through this boundary.

Every business job must define its own stable `JobArgs.Kind()` and JSON args. Do not reintroduce a generic `hub_task` envelope: River dashboards, logs, alerts, and manual operations must expose the business kind directly. Put variable dimensions such as locale in args rather than suffixing the kind. Register with `taskqueue.Register`, optionally pair a terminal business-state transition through `RegisterFailureHandler`, then submit the same args type through `Runtime.Enqueue`, `Runtime.EnqueueTx`, or `Runtime.Every`.

For atomic Catalog mutation and task submission, call `Runtime.EnqueueTx` only with the native `pgx.Tx` supplied by `Catalog.WithPostgresTx`, and bind sqlc queries to that same transaction. `Runtime.Enqueue` is intentionally non-transactional and must not follow a separately committed domain mutation when atomicity is required. Task handlers must remain idempotent because River provides at-least-once execution.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
