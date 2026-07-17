# Artifact Download Protocol
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `protocol.go`, `handler.go`, and version-specific handlers: expose immutable artifact list, info, manifest, ZIP, latest, and selector-resolution HTTP routes over composable storage and source protocols.
- `version_resolve.go`: preserves exact immutable versions and resolves default latest-stable, npm-style SemVer constraints, and literal Git revisions into one immutable artifact version.
- `addons/` and `mode/`: wrap protocol execution with concurrency control and synchronous or redirect delivery policy.
- `*_test.go`: specify the public HTTP and Protocol contracts, including selector resolution, caching, fallback, and artifact delivery.

## Architectural Boundary

This module owns the public artifact distribution and version-resolution protocol. It may select repository versions exposed by source listing and resolution, but it must not persist CLI manifests, choose local Agent targets, or infer installation scope.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
