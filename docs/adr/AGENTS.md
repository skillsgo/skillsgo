# System ADRs
> Decision Map | Parent: `/AGENTS.md`

## Members

- `0001-bundle-skillsgo-cli.md`: establishes the bundled CLI as the shared local execution engine for the App and terminal users.
- `0002-name-public-distribution-context-hub.md`: establishes SkillsGo Hub as the shared product and domain name for public Skill discovery and distribution.
- `0003-use-public-skill-ids.md`: records the superseded concatenated public Skill ID design that was replaced before public launch.
- `0004-separate-package-and-api-surfaces.md`: records the superseded `/mod`, `skillsgo.mod`, and `skillsgo.sum` separation design that was replaced before public launch.
- `0005-route-app-through-cli-and-stabilize-machine-failures.md`: makes the CLI the App's only business-integration boundary and establishes the minimal public machine-failure contract for App and automation callers.
- `0006-trust-skills-sh-locks-for-batch-takeover.md`: records the superseded exact-lock and immutable-byte-verification takeover design replaced by ADR-0013.
- `0007-host-public-web-on-cloudflare.md`: establishes the independent SkillsGo Web workspace and Cloudflare deployment boundary for product, Hub discovery, and documentation pages.
- `0008-backfill-repository-history.md`: establishes authenticated Hub-admin Repository Backfill, independent asynchronous runs, and shared Catalog current recomputation.
- `0009-freeze-hub-v1-distribution-contract.md`: records the superseded per-Skill artifact and installation-mode design that was replaced before public launch.
- `0010-distribute-repository-versions-and-project-selected-skills.md`: makes Repository Version the artifact, Sum, download, lock, and Package Store unit while preserving Skill-level Agent visibility through deterministic Repository Projections.
- `0011-identify-repository-members-by-skill-name.md`: identifies selectable members by Repository ID plus canonical Skill Name, keeps Skill Path internal to a Publication, and removes public Skill IDs and `/-/`.
- `0013-require-user-reviewed-external-skill-adoption.md`: makes External Skill adoption a user-reviewed Hub candidate and immutable-version selection, permits multiple versions of one Repository per scope, and requires 30-day per-Skill recovery.
- `0014-localize-presentation-content-without-translating-artifacts.md`: localizes descriptions and display-only Skill documents across the Hub, Protocol, CLI, and App while keeping Package Artifacts and Agent execution source-only.
- `0015-make-package-updates-scope-aware.md`: makes `Scope × Package Path` the update target, unifies preview and execution under `skillsgo update`, and replaces Skill-level availability checks with Package-level Hub reads.
- `0016-distribute-package-artifacts-as-static-git-repositories.md`: proposes replacing immutable per-version ZIPs with Hub-authored bare Git Artifact Repositories distributed from Cloudflare-backed R2 over dumb HTTP.
- `0017-rebuild-disposable-package-caches-and-materialize-scope-trees.md`: makes exact metadata/Git state disposable read-through cache, separates Global declarations under `~/.agents` from the Global Package Tree under the SkillsGo State Root, and preserves complete Scope Trees plus protected platform-native member links.
- `0018-use-a-long-lived-cli-server-for-the-app.md`: keeps one sequential NDJSON CLI process behind the App so Go HTTP connections survive across operations, with explicit crash recovery and non-replay semantics.
- `0019-publish-conventional-skill-directory-subtrees.md`: adopts skills.sh-compatible convention-first discovery and limits each filtered Package Artifact to accepted self-contained Skill directory subtrees plus applicable plugin manifests.
- `0020-publish-only-package-content-transitions.md`: publishes only filtered Package content transitions while retaining duplicate upstream revisions as exact, artifact-free equivalent Versions.
- `0021-report-package-installs-as-batch-events.md`: reports one Package transaction as one best-effort event with embedded Skill facts, CLI version, and optional App version.
- `0022-publish-authenticated-standalone-cli-releases.md`: establishes independent CLI tags, exact cross-platform archives, signed CDN Manifests, fixed update trust, and check-only source-aware self-update behavior.
- `0023-bootstrap-projects-from-agent-sessions.md`: seeds an empty CLI-owned project registry from bounded local supported-Agent registries and session metadata before the App loads Added Projects.

## Architectural Boundary

This directory owns decisions that cross two or more SkillsGo contexts. App-only, CLI-only, and Hub-only decisions belong in the owning context's `docs/adr/` directory.

When adding, removing, renaming, superseding, or moving a system ADR, update this member list in the same change.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
