# Skill Source Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `id.go`, `id_test.go`: adapt the shared Protocol public Skill ID grammar to Hub source-resolution call sites and specify Hub-supported repository constraints.
- `manifest.go`, `manifest_test.go`: adapt shared Protocol `SKILL.md` extraction and validation to Hub source publication.
- `fetcher.go`: defines source resolution, immutable artifact fetch, Repository snapshot discovery, and upstream version-listing contracts.
- `git_fetcher.go`, `git_helpers.go`, `repository_cache.go`, `repository_cache_test.go`: resolve Git revisions with ancestor-tag-based pseudo-version ordering, scan one Repository commit for repository-owned Skill candidates while excluding hidden installation directories, enforce public-host/redirect/disk boundaries, protect active mirrors with process-local leases, reclaim inactive mirrors by TTL and least-recently-used aggregate quota, share repository snapshots safely across root and nested Skills, and emit bounded correlated Git transport diagnostics.
- `git_artifact_fetcher.go`, `git_artifact_fetcher_test.go`: configure Git-backed fetching and GitHub credential pools, assemble immutable Skill artifacts from resolved Git trees, and validate source metadata.
- `go_vcs_lister.go`, `upstream_lister.go`: expose upstream version discovery over the repository resolver.
- `latest_test.go`, `version_matrix_test.go`, `pseudo_version_validation_test.go`, `go_derived_version_test.go`: specify stable-first semantic-version selection, the table-driven C1/C2, F1/F2, V1, and cache-freshness query matrix, plus selected Go-derived pseudo-version authenticity, generation, odd-Tag, and semantic-revision rules shared by lazy resolution.
- `filter.go`, `filterRule.go`, `filter_rule.go`, `filter_test.go`: preserve inherited source filtering behavior.
- `zip_compression.go`, `zip_compression_test.go`, `zip_read_closer.go`, `zip_read_closer_test.go`: assemble bounded deterministic SkillsGo artifacts from Git without Go Module path semantics, preserve safe archive identity, and provide bounded ZIP readers.
- `all_test.go`: provides shared package-level test setup.

## Architectural Boundary

This module owns source revision resolution, Hub publication decisions, bounded Git transport, and immutable artifact assembly. Shared public Skill ID and manifest grammar belong to the Protocol workspace. Private-address Git hosts require the explicit `SKILLSGO_ALLOW_PRIVATE_GIT_HOSTS` operator opt-in. It must not persist Catalog metadata, render HTTP responses, install local targets, or infer App presentation state.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
