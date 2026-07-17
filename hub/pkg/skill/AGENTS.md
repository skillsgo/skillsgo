# Skill Source Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `id.go`, `id_test.go`: define canonical public Skill ID parsing, formatting, repository addressing, and hostile-input rejection.
- `manifest.go`, `manifest_test.go`: extract and validate `SKILL.md` frontmatter, names, descriptions, and instruction bodies.
- `fetcher.go`: defines source resolution, immutable artifact fetch, Repository snapshot discovery, and upstream version-listing contracts.
- `git_fetcher.go`, `git_helpers.go`, `repository_cache_test.go`: resolve Git revisions and share repository caches safely across root and nested Skills.
- `git_artifact_fetcher.go`, `git_artifact_fetcher_test.go`: assemble immutable Skill artifacts from resolved Git trees and validate source metadata.
- `git_fetcher.go`: resolves revisions, scans one Repository commit for valid Skill candidates, and shares one synchronized source snapshot across member artifacts.
- `go_vcs_lister.go`, `upstream_lister.go`: expose upstream version discovery over the repository resolver.
- `latest_test.go`: specifies stable-first semantic-version selection shared by lazy latest resolution.
- `filter.go`, `filterRule.go`, `filter_rule.go`, `filter_test.go`: preserve inherited source filtering behavior.
- `zip_compression.go`, `zip_compression_test.go`, `zip_read_closer.go`, `zip_read_closer_test.go`: provide deterministic archive compression and bounded ZIP readers.
- `all_test.go`: provides shared package-level test setup.

## Architectural Boundary

This module owns public Skill ID parsing, source revision resolution, manifest validation, and immutable artifact assembly. It must not persist Catalog metadata, render HTTP responses, install local targets, or infer App presentation state.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
