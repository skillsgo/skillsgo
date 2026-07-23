# ADR 0012: Compose Cloud Rankings with Hub Cards

## Context

The App previously fetched ordered ranking coordinates and metrics directly from SkillsGo Cloud, then started the bundled CLI to hydrate those coordinates through the Hub batch endpoint. This added a serial process and network boundary to every ranking load. The Hub batch implementation also issued one database query per coordinate, while stale Cloud coordinates could produce sparse pages after client-side hydration.

## Decision

SkillsGo Cloud composes each public ranking response from Cloud-owned ordered metrics and authoritative Hub Skill cards. Cloud calls the public Hub batch endpoint, preserves ranking order, omits coordinates absent from the current Hub Catalog, and does not persist Hub metadata.

Concurrent Cloud requests for the same ordered coordinate batch share one in-flight Hub request through singleflight. Completion, success, and failure are not cached; a later request always reads Hub again. The Hub batch endpoint resolves all requested coordinates through one ordered SQL query rather than per-coordinate queries.

The App continues to discover the Cloud origin through CLI-mediated `hub info`, then reads the composed ranking response directly from Cloud. It does not call Hub HTTP directly and no longer starts a CLI detail process for ranking-card hydration.

## Consequences

- Ranking page loads use one App-to-Cloud request after deployment discovery.
- Hub remains authoritative for Skill metadata, while Cloud remains authoritative for ranking metrics and ordering.
- Cloud availability depends on the public Hub batch endpoint for non-empty ranking responses, but the Hub never depends on Cloud.
- Singleflight reduces duplicate concurrent Hub traffic without introducing stale completed-result caching.
- Cloud and Hub databases remain independent and have no cross-database joins or foreign keys.
