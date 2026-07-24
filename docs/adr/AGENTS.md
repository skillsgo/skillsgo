# System ADRs
> Decision Map | Parent: `/AGENTS.md`

## Members

- `0001-bundle-skillsgo-cli.md`: establishes the bundled CLI as the shared local execution engine for the App and terminal users.
- `0002-name-public-distribution-context-hub.md`: establishes SkillsGo Hub as the shared product and domain name for public Skill discovery and distribution.
- `0003-use-public-skill-ids.md`: records the superseded concatenated public Skill ID design that was replaced before public launch.
- `0004-separate-module-and-api-surfaces.md`: records the superseded `/mod`, `skillsgo.mod`, and `skillsgo.sum` separation design that was replaced before public launch.
- `0005-route-app-through-cli-and-stabilize-machine-failures.md`: makes the CLI the App's only business-integration boundary and establishes the minimal public machine-failure contract for App and automation callers.
- `0006-trust-skills-sh-locks-for-batch-takeover.md`: records the superseded exact-lock and immutable-byte-verification takeover design replaced by ADR-0013.
- `0007-host-public-web-on-cloudflare.md`: establishes the independent SkillsGo Web workspace and Cloudflare deployment boundary for product, Hub discovery, and documentation pages.
- `0008-backfill-repository-history.md`: establishes authenticated Hub-admin Repository Backfill, independent asynchronous runs, and historical publication visibility.
- `0009-freeze-hub-v1-distribution-contract.md`: records the superseded per-Skill artifact and installation-mode design that was replaced before public launch.
- `0010-distribute-repository-versions-and-project-selected-skills.md`: makes Repository Version the artifact, Sum, download, lock, and Vendor unit while preserving Skill-level Agent visibility through deterministic Repository Projections.
- `0011-identify-repository-members-by-skill-name.md`: identifies selectable members by Repository ID plus canonical Skill Name, keeps Skill Path internal to a Publication, and removes public Skill IDs and `/-/`.
- `0012-compose-cloud-rankings-with-hub-cards.md`: makes Cloud the ranking composition boundary through uncached singleflight Hub batch reads and requires one-query ordered Hub hydration.
- `0013-require-user-reviewed-external-skill-adoption.md`: makes External Skill adoption a user-reviewed Hub candidate and immutable-version selection, permits multiple versions of one Repository per scope, and requires 30-day per-Skill recovery.
- `0014-distribute-source-independent-packages.md`: replaces Git Repository-first distribution with source-independent Package Publications, typed Source Adapters, exact Package-member identity, multi-Publication local state, and a no-compatibility cross-context implementation plan.

## Architectural Boundary

This directory owns decisions that cross two or more SkillsGo contexts. App-only, CLI-only, and Hub-only decisions belong in the owning context's `docs/adr/` directory.

When adding, removing, renaming, superseding, or moving a system ADR, update this member list in the same change.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
