# Skill Source Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `id.go`, `id_test.go`: adapt the shared Protocol public Repository ID grammar to Hub source-resolution call sites and specify Hub-supported repository constraints.
- `manifest.go`, `manifest_test.go`: adapt shared Protocol `SKILL.md` extraction and validation to Hub source publication.
- `fetcher.go`: defines source resolution, complete Repository Artifact snapshots, ordered validated Skill membership, explicit leased Backfill sessions, and upstream version-listing contracts.
- `source_failure.go`, `source_failure_test.go`: define and verify stable non-sensitive Source Failure Codes shared with Package History Backfill without exposing Git transport details.
- `discovery.go`, `discovery_test.go`: implement and specify the pure skills.sh-compatible convention-first candidate tiers, bounded recursive fallback, and minimal accepted Skill directory unions with optional authored root README preservation.
- `plugin_manifest.go`, `plugin_manifest_test.go`: preserve authored root plugin identity, reject conflicting Agent namespaces, and deterministically complete missing Codex, Claude, and Cursor manifests from Package identity and accepted Skill paths.
- `git_fetcher.go`, `git_helpers.go`, `repository_cache.go`, `repository_cache_test.go`: resolve Git revisions with ancestor-tag-based pseudo-version ordering, support snapshot visitation over one synchronized leased Source Repository, validate convention-first Skill membership by tier, build filtered Package Artifacts from selected Skill subtrees and applicable plugin manifests, enforce public-host/redirect/disk boundaries, protect active mirrors with process-local leases, reclaim inactive mirrors by TTL and least-recently-used aggregate quota, and emit bounded correlated Git transport diagnostics.
- `go_vcs_lister.go`, `upstream_lister.go`: expose ordinary upstream version discovery plus Backfill preparation that synchronizes once, derives a bounded Tag or pseudo-version catalog, and retains the same Repository lease through all selected snapshot visits.
- `git_artifact_fetcher.go`, `git_artifact_fetcher_test.go`: configure Git-backed Repository fetching and GitHub credential pools, assemble immutable Repository Artifacts from resolved Git trees, and validate source metadata.
- `latest_test.go`, `version_matrix_test.go`, `pseudo_version_validation_test.go`, `go_derived_version_test.go`: specify stable-first semantic-version selection, the table-driven C1/C2, F1/F2, V1, and cache-freshness query matrix, plus selected Go-derived pseudo-version authenticity, generation, odd-Tag, and semantic-revision rules shared by lazy resolution.
- `filter.go`, `filterRule.go`, `filter_rule.go`, `filter_test.go`: preserve inherited source filtering behavior.
- `zip_compression.go`, `zip_compression_test.go`: adapt selected Package Git tar streams into the shared bounded Package Artifact tree contract without constructing ZIPs, preserve the authored root README, complete cross-Agent plugin manifests, discard tar/PAX transport metadata, preserve safe Package-contained symlinks, omit unsafe links, and prove Sum equivalence with the legacy deterministic ZIP projection.
- `real_repository_benchmark_test.go`: opt-in allocation and wall-time benchmarks of the production Artifact projection path and repeated-versus-one-sync Backfill source synchronization against the maintained five-repository local corpus; they are excluded from ordinary CI when the corpus environment variable is absent.
- `all_test.go`: provides shared package-level test setup.

## Architectural Boundary

This module owns source revision resolution, Hub publication decisions, bounded Git transport, and immutable artifact assembly. Shared public Repository ID and Skill manifest grammar belong to the Protocol workspace. Private-address Git hosts require the explicit `SKILLSGO_ALLOW_PRIVATE_GIT_HOSTS` operator opt-in. It must not persist Catalog metadata, render HTTP responses, install local targets, or infer App presentation state.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
