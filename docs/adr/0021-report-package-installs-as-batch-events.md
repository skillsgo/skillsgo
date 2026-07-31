# ADR-0021: Report Package Installs as Batch Events

## Status

Accepted

## Context

One Package installation can select many Skills and Agents while committing one local transaction. Reporting one synchronous HTTP request per selected Skill makes community telemetry latency grow linearly with Package membership and misrepresents one user action as many independent installation events.

The public event must also distinguish the CLI that performed the transaction from an optional SkillsGo App version that invoked that CLI.

## Decision

The CLI reports one best-effort Package Install Event after each successful Package transaction.

The event contains:

- one immutable Package Path and Version;
- the complete non-empty selected `{name, path}` Skill set;
- the complete non-empty Agent set and one Scope;
- one Event ID and occurrence time;
- the CLI version;
- an optional calling App version.

Skill Path is unique within the event. The public contract permits at most 100 Skills in one event.

The CLI sends one request for the transaction. Reporting failure never changes a successful local installation result.

Consumers persist the Package event once and may normalize its Skill members into child facts for ranking and aggregation. Event-ID replay with identical canonical content is idempotent; reuse with different content is a conflict.

## Consequences

- Reporting latency no longer scales with the number of selected Skills.
- Package-level provenance is retained without losing per-Skill ranking facts.
- App and CLI versions remain independently queryable.
- Producers and consumers adopt the batch schema as a hard cut; no legacy per-Skill payload is accepted.
