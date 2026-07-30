---
status: accepted
---

# Compose the Official Cloud Runtime from the Complete Hub

## Context

SkillsGo currently deploys the public Hub and the private SkillsGo Cloud as separate processes backed by independent PostgreSQL databases. The Hub owns public Package and Skill identity, source resolution, immutable Package publication, Artifact Repository production, search, localization, Package History Backfill, River jobs, and related background work. Cloud owns installation-event facts, external adoption observations, aggregate statistics, and ranking projections.

ADR-0012 placed ranking composition in Cloud. Cloud first reads ordered metrics from its own database and then calls public Hub HTTP endpoints to resolve missing Skill Paths and hydrate authoritative localized Skill cards. The App separately persists Hub and Cloud Origins, reads rankings from Cloud, and routes Hub operations through the bundled CLI. After installation, the CLI discovers a Cloud Origin from Hub and reports the event to that second Origin.

This topology preserves deployment isolation, but its operational cost is no longer justified. It requires two application services, two PostgreSQL services, two public Origins, duplicated HTTP and observability assembly, Cloud-to-Hub network calls, duplicated JSON validation, and client-side deployment discovery. The project has accumulated Catalog, installation, and ranking data, but it does not yet have active production users. A maintenance-window replacement is therefore acceptable: services may be stopped, historical data may be copied once, and no dual-write, incremental synchronization, traffic shadowing, or legacy deployment fallback is required.

The target must not reduce Cloud to a ranking sidecar around a partial Hub library. The official Cloud runtime must contain the complete Hub capability set, including all public Hub routes, source and Package resolution, immutable publication, Artifact Repository operations, foreground and background Catalog pools, River jobs, Package History Backfill, metadata refresh, translation dispatch and workers, storage adapters, administration, observability, and coordinated shutdown. A separately released Hub must remain usable for self-hosting without depending on private Cloud code.

## Decision

SkillsGo Cloud becomes the composition root and sole official online process. Its Go module depends on a released SkillsGo Hub Go module and embeds the complete Hub Runtime. The dependency direction is permanently:

```text
SkillsGo Cloud -> SkillsGo Hub -> SkillsGo Protocol
SkillsGo Cloud ----------------> SkillsGo Protocol
```

Hub never imports Cloud. The official runtime is built and deployed from the private Cloud repository, while the public Hub repository continues to release an independently runnable self-hosted binary and image from the same embeddable Hub Runtime implementation.

### One public Origin and one protocol surface

`https://hub.skillsgo.ai` remains the only official dynamic API Origin. The official Cloud-composed process serves every Hub and Cloud-owned route from that Origin. `cloud.skillsgo.ai` and independent Cloud Origin configuration are removed without compatibility redirects.

Hub owns the complete public HTTP protocol surface, including:

```text
/api/v1/events/install
/api/v1/rankings/all_time
/api/v1/rankings/trending
/api/v1/rankings/hot
```

Hub defines a narrow in-process community-data interface used by those handlers. The interface records a validated installation event and returns a validated ranking projection. Hub supplies an empty implementation for self-hosting; the official Cloud runtime supplies the persistent implementation.

The self-hosted empty implementation has these semantics:

- a valid install event returns `202 Accepted` with `{"accepted":false}` and is not retained;
- an invalid install event receives the same validation failure as the official implementation;
- every valid ranking request returns `200 OK`, an empty `skills` array, and terminal pagination;
- invalid ranking kinds, pagination, and languages receive the same validation failure as the official implementation;
- no Cloud tables, background jobs, external observations, or private dependencies are required.

The official implementation stores event and external-observation facts in the Cloud schema, calculates ordering and metrics there, and reads authoritative cards through the injected Hub Catalog in the same process. It does not call Hub HTTP and does not issue SQL against Hub tables. Its adapter translates Cloud ranking coordinates into the existing Hub Catalog batch operations, preserves ranking order, omits coordinates absent from the current Catalog, and applies Hub-owned localization and current-Version semantics.

Hub registers these routes exactly once. Cloud does not create a second nested Fiber application or register competing copies of the routes. The standalone Hub App and official Cloud App follow the same composition pattern: each creates its caller-owned outer Fiber App and mounts the same exported Hub modules into it. The Hub App supplies the empty community-data implementation; the Cloud App supplies the persistent implementation. Each composition root initializes its process-level HTTP middleware, request correlation, OpenAPI, tracing, metrics, health handling, listening, and shutdown exactly once.

### Complete embeddable Hub Runtime

The Hub repository extracts its current process assembly into exported, lifecycle-managed modules. The standalone Hub App and official Cloud App mount those modules through the same interface and code style; neither embeds an already assembled Hub App as a nested application. The exported Runtime owns the complete Hub behavior rather than exposing a Catalog-only subset. At minimum it owns:

- public catalog, Package distribution, administration, health, and documentation routes;
- foreground and background Catalog pools;
- source Repository resolution and controlled Git work;
- immutable Package publication and Artifact Repository storage;
- Package History Backfill and its durable business state;
- River initialization, registration, scheduling, and workers;
- Repository metadata refresh work;
- description and Skill-document language analysis and translation dispatch;
- translation workers, retry policy, and persisted outcomes;
- configured storage, GitHub, translation, logging, tracing, and metrics adapters;
- readiness and coordinated worker, exporter, pool, and storage cleanup.

The Runtime exposes only the composition operations Cloud needs: construction, route registration, readiness, shutdown, and access to the authoritative Catalog read module required by the Cloud adapter. Cloud must not import Hub command packages, generated sqlc packages, migration internals, or table definitions.

### Client behavior and removal of capability discovery

The App and CLI retain one configurable Hub Origin and remove every independently persisted or discovered Cloud Origin. Ranking reads use the current Hub Origin. Installation-event reporting posts directly to the current Hub Origin after the local installation transaction commits and remains best effort: reporting failure never changes the local installation result.

Deployment capability discovery is deleted. `/api/v1/capabilities`, `/api/v1/info`, Hub deployment `mode`, Cloud Origin fields, and their configuration and tests no longer choose client behavior. Every Hub implements the complete v1 route surface; a self-hosted Hub expresses the absence of community data through successful empty results, not through route absence or feature negotiation. A future incompatible public protocol uses a new path version instead of reviving runtime capability negotiation.

### One PostgreSQL database with two owned schemas

The official deployment uses one PostgreSQL database with three schemas:

```text
public  shared PostgreSQL extensions only
hub     Hub Catalog, River, and Hub migration history
cloud   install facts, aggregate statistics, external observations, and Cloud migration history
```

Hub and Cloud retain separate schema ownership, Atlas migration histories, advisory migration locks, sqlc query sets, and fixed connection pools. The process uses:

- a Hub foreground pool with `search_path=hub,public`;
- a Hub background pool with `search_path=hub,public`;
- a Cloud pool with `search_path=cloud,public`.

Pools are not shared and request code never changes `search_path` dynamically. Cloud does not join or reference Hub tables from Cloud SQL. The in-process Hub Catalog interface, not a cross-schema query, is the seam between the domains.

Separate runtime database roles are preferred: the Hub role reads and writes `hub`, while the Cloud role reads and writes `cloud`. The Cloud process may hold both credentials because it composes both modules, but the Cloud pool receives no write authority over `hub`. A distinct migrator role may own schema and extension changes. Initial deployment may temporarily use one Railway-provided database role if the platform makes role provisioning disproportionate, but fixed pools and schema ownership remain mandatory.

### Official deployment

The private Cloud repository builds the only official online image. That image contains the Cloud implementation and the complete released Hub Runtime, including every system dependency required by Hub Git and Artifact operations. The public Hub repository continues to publish its standalone self-host image, but the official Railway project does not deploy it.

The target production topology is:

```text
Cloudflare DNS/proxy
  hub.skillsgo.ai
    -> one Railway application service built from skillsgo-cloud
       -> one Railway PostgreSQL service
          -> hub schema
          -> cloud schema
       -> Cloudflare R2 Artifact Repository storage
```

The Railway application normally runs one replica to minimize baseline resource use. Rolling overlap is not required for the initial replacement. Subsequent deployments may use ordinary bounded overlap, so pool limits must leave capacity for two transient process instances.

The combined binary provides explicit `migrate`, `serve`, and deep diagnostic commands. Production deployment runs both schema migrations before serving. Startup fails if either schema cannot migrate or either required Runtime cannot initialize. `/healthz` reports process liveness. `/readyz` reports readiness only after both Hub and Cloud databases and the complete Hub Runtime are ready. Optional external systems such as skills.sh and translation providers do not make the HTTP runtime unready after a successful local initialization; their failures are observable degraded background states.

Shutdown first withdraws readiness and stops accepting new requests, then drains HTTP work, the skills.sh scheduler, River and Hub background workers, telemetry exporters, Cloud persistence, Hub background persistence, and Hub foreground persistence within one bounded process deadline.

### Direct replacement and historical data migration

The first production deployment is a planned hard cut. There is no dual-write, incremental replication, compatibility service, traffic split, or fallback to the two-service topology.

Before the cut, the implementation must provide and test the combined Runtime, both schema migrations, and a versioned one-shot data importer or an equivalently reviewed table-explicit import script. The importer connects to the old Hub database, old Cloud database, and empty migrated target database. It refuses a non-empty target and copies only product facts.

The migration proceeds as follows:

1. Build and validate the final combined image in an isolated environment with the same one-database, two-schema topology.
2. Create the new PostgreSQL database and required runtime or migration roles.
3. Run the combined binary's migrations to create `hub`, `cloud`, their independent `atlas_schema_revisions` tables, Hub River tables, and shared extensions in `public`.
4. Stop the old Cloud service so no additional installation events or provider observations can be written.
5. Stop the old Hub service and all Hub background workers so Catalog, Backfill, translation, metadata, and publication state cannot advance.
6. Take final backups of both source databases and record table counts and aggregate checksums used for verification.
7. Copy Hub product data into `hub` in foreign-key order, including Packages, Versions, Skills, localization outcomes, Repository metadata, and durable Backfill business outcomes that remain semantically useful.
8. Do not copy Hub or Cloud `atlas_schema_revisions`, River transport tables, leases, heartbeats, process caches, or queued/running operational work. The target owns fresh migration history and replans background work from durable product state.
9. Copy Cloud product data into `cloud`, including immutable install events, aggregate Package-Skill statistics, completed provider crawls, their retained raw pages, and normalized observations. Do not copy provider synchronization leases or incomplete crawls.
10. Reset every target identity sequence to at least the maximum imported key.
11. Validate row counts, primary and foreign keys, current Package Version references, Skill membership, localization references, install-event uniqueness, aggregate install totals, completed provider observations, and representative all-time, trending, and hot rankings.
12. Run deep combined-runtime diagnostics and smoke journeys covering search, Package Info, exact Artifact restoration, one idempotent installation event, every ranking kind, Hub-card hydration, Backfill submission, River execution, metadata refresh, and translation dispatch.
13. Deploy one combined Railway replica, require `/readyz` success, and bind `hub.skillsgo.ai` to it.
14. Update App and CLI defaults and settings to the single Hub Origin and remove Cloud Origin behavior.
15. Keep final source backups for a short operational verification period, then delete the two old Railway application services, their databases, Cloud hostname, obsolete secrets, and obsolete monitoring.

An import failure is repaired offline and rerun against a newly emptied target schema. Because there are no active production users, availability during this procedure is not a requirement. Rollback before DNS binding means discarding the target and restarting the stopped old services from their unchanged databases. After DNS binding and acceptance, rollback is only to a previous combined image compatible with the migrated schemas; the independent topology is not retained as a product fallback.

## Consequences

- The official baseline becomes one application service and one PostgreSQL service while retaining Hub and Cloud domain ownership through modules, schemas, migrations, pools, and database roles.
- Cloud contains every Hub online and background capability. Search, publication, storage, Backfill, River, metadata refresh, translation, and administration do not remain in a second official process.
- Cloud ranking composition removes its Hub HTTP client, JSON round trips, timeout configuration, HTTP singleflight, and `HUB_URL` dependency.
- `hub.skillsgo.ai` is the only client Origin. App and CLI remove independent Cloud settings and deployment discovery.
- Self-hosted Hub installations remain protocol-complete and require no Cloud database; installation events are discarded explicitly and rankings are valid empty collections.
- Hub remains independently releasable. Cloud pins a released Hub module version and validates the complete combined Runtime before deployment.
- One process has a larger failure domain. Pool budgets, worker concurrency, background degradation, readiness, and coordinated shutdown must prevent Hub background activity from exhausting interactive Hub and Cloud work.
- One database instance has a larger infrastructure failure domain. Schema isolation prevents ownership drift but does not provide instance-level fault isolation.
- The initial cut accepts downtime and operational simplicity because no active production users require continuous availability. Historical product data is retained without preserving obsolete runtime state.
- ADR-0012 is superseded. Its Cloud-to-Hub HTTP composition, independent Origins, separate databases, and independent deployment conclusions no longer apply; its ownership principle remains: Cloud owns ranking metrics and Hub owns authoritative Skill cards.

## Rejected Alternatives

### Keep separate services but share one PostgreSQL instance

This reduces database cost but retains two application processes, duplicated runtime assembly, Cloud-to-Hub networking, two Origins, and client discovery. It does not achieve the intended operational simplification.

### Let Cloud query `hub` tables directly

Cross-schema SQL would make Cloud depend on Hub's migration layout, current-Version rules, localization behavior, and generated persistence implementation. The in-process Hub Catalog module provides a deeper and more stable seam.

### Embed only Hub Catalog reads in Cloud

This would leave publication, Artifact work, Backfill, River, metadata refresh, translation, administration, and other Hub behavior in a second official service. Cloud must compose the complete Hub Runtime, not bolt new wheels onto the old deployment.

### Make Hub depend on private Cloud

This would invert ownership, prevent a clean public self-hosted Hub release, and expose private deployment concerns to Hub. Cloud is the outer composition root and therefore depends on Hub.

### Preserve Cloud Origin and capabilities during a transition

There are no active production users requiring a compatibility window. Retaining discovery and dual routing would create transitional behavior that has no target-state purpose. The protocol remains complete through Hub's empty self-host implementation.

### Perform a zero-downtime incremental migration

Dual writes, change capture, catch-up verification, and traffic splitting add failure modes without serving a current availability requirement. A stopped, backed-up, table-explicit copy is easier to verify and discard on failure.
