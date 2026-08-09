# Hub Client Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `client.go`: resolves exact versions or movable Version Queries through `/{packagePath}/versions/{version}`, follows Package Info to static Git Artifact repositories, resolves member names deterministically while preserving exact Skill path selectors, forwards version-scoped Skill Find plus source-language candidate, current-Package, and Package update-check product APIs, validates strict provider-neutral `/api/v1` responses, verifies Package identity/Sum, and exposes typed HTTP failures.
- `git_artifact.go`: uses go-git v6 with forced dumb HTTP to cache each repository under its readable Go-escaped Package Path, read one exact parentless tag from CDN-hosted static repository files, automatically rebuild one corrupt disposable repository coordinate, and restore validated Package entries without invoking system Git.
- `git_artifact_test.go`: specifies readable Package-Path cache coordinates and case-safe Go path escaping.
- `client_test.go`: specifies strict Repository transport contracts, hostile response rejection, retries, and download progress.

## Architectural Boundary

This module owns the CLI's public Hub transport client and consumer-side artifact-integrity enforcement. Shared wire types, artifact algorithms, identity grammar, locale normalization, and version-selection rules belong to the Protocol workspace. It must not persist local installation state, infer installation targets, or expose human-oriented response parsing to the App.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
