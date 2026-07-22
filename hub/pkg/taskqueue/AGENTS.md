# Hub Task Queue Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `runtime.go`: defines type-safe River job/finalizer registration, bounded source/default/maintenance worker allocation, exact active-job lookup for domain reconciliation, pre-start periodic registration, synchronous SQLite-compatible scheduling, configurable failure detection, and PostgreSQL execution without a generic envelope.
- `runtime_test.go`: verifies typed synchronous dispatch, terminal finalization, periodic cancellation, registration freezing, unknown job rejection, and lifecycle behavior.
- `postgres_integration_test.go`: verifies River schema migration, periodic execution, transient-failure retry, `MaxAttempts` exhaustion into `discarded`, cross-client uniqueness, durable submission, and execution against opt-in real PostgreSQL.
- `crash_recovery_integration_test.go`: force-kills a subprocess during handler execution and verifies a replacement River process rescues and re-executes the durable running job.

## Architectural Boundary

This module owns durable asynchronous task transport and local synchronous substitution. It must not own Hub domain decisions, persist business state outside River tables, or make handlers non-idempotent.

Business handlers are registered during service assembly and frozen by `Start`. Use `Runtime.Every` for recurring work instead of package-owned tickers. PostgreSQL uses River's durable periodic jobs; SQLite development uses the same handler contract with an in-process scheduler. The Hub currently routes artifact stashing, description translation, Repository source-metadata refresh, and Repository prewarming through this boundary.

Every business job must define its own stable `JobArgs.Kind()` and JSON args. Do not reintroduce a generic `hub_task` envelope: River dashboards, logs, alerts, and manual operations must expose the business kind directly. Put variable dimensions such as locale in args rather than suffixing the kind. Register with `taskqueue.Register`, optionally pair a terminal business-state transition through `RegisterFailureHandler`, then submit the same args type through `Runtime.Enqueue`, `Runtime.EnqueueTx`, or `Runtime.Every`.

For atomic Catalog mutation and task submission, call `Runtime.EnqueueTx` only with the native `pgx.Tx` supplied by `Catalog.WithPostgresTx`; use the callback-scoped Ent client for every accompanying domain write. `Runtime.Enqueue` is intentionally non-transactional and must not follow a separately committed domain mutation when atomicity is required. Task handlers must remain idempotent because River provides at-least-once execution.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
