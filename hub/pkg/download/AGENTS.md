# Artifact Download Protocol
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `protocol.go`, `handler.go`, and version-specific handlers: expose the JSON `/api/v1/{packagePath}/versions` collection and Version-Query-resolving `/api/v1/{packagePath}/versions/{version}` metadata over source discovery and Catalog decorators; Artifact bytes are distributed only from static Git repository URLs carried by Package Info.
- `*_test.go`: specify the public HTTP and Protocol contracts, including version listing, caching, and metadata delivery.

## Architectural Boundary

This module owns Package discovery and metadata HTTP routing. It does not read Artifact object storage and exposes no archive byte route. It may expose Package Versions supplied by source listing and Catalog publication history, but it must not persist CLI Workspace Manifests, choose local Agent targets, or infer installation scope.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
