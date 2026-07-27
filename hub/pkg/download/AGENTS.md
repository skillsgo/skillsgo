# Artifact Download Protocol
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `protocol.go`, `handler.go`, `immutable_etag.go`, and version-specific handlers: expose the JSON `/api/v1/{packagePath}/versions` collection, Version-Query-resolving `/api/v1/{packagePath}/versions/{version}` metadata, and immutable-only GET `/api/v1/{packagePath}/versions/{version}.zip` resources over composable storage and source protocols; enforce conditional cache and method contracts, stream files with EOF-bound resource closure, redirect canonical immutable ZIPs to a configured artifact origin after materialization, and retain structured observability.
- `*_test.go`: specify the public HTTP and Protocol contracts, including version listing, caching, fallback, and artifact delivery.

## Architectural Boundary

This module owns the public Package distribution protocol. It may expose Package Versions supplied by source repository listing and resolution, but it must not persist CLI Workspace Manifests, choose local Agent targets, or infer installation scope.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
