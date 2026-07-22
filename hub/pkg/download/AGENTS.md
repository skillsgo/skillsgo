# Artifact Download Protocol
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `protocol.go`, `handler.go`, `immutable_etag.go`, and version-specific handlers: expose `/mod`-namespaced List, explicit Head/Release Selectors, Info, and Skill ZIP routes over composable storage and source protocols, enforce method and conditional-request contracts, submit async/async-redirect cache misses to the durable Hub task runtime, redirect canonical immutable ZIPs to a configured artifact origin after materialization, distinguish immutable and movable HTTP caching, and retain structured cache and dispatch observability.
- `addons/` and `mode/`: wrap protocol execution with concurrency control and synchronous or redirect delivery policy.
- `*_test.go`: specify the public HTTP and Protocol contracts, including version listing, caching, fallback, and artifact delivery.

## Architectural Boundary

This module owns the public artifact distribution protocol. It may expose Repository versions supplied by source listing and resolution, but it must not persist CLI Workspace Manifests, choose local Agent targets, or infer installation scope.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
