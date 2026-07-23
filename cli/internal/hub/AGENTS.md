# Hub Client Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `client.go`: delegates version selectors to the root Repository Proxy, consumes typed Repository/member Info and product API DTOs, forwards optional presentation locales for discovery/detail, validates strict provider-neutral `/api/v1` reads, downloads bounded Repository ZIP responses with optional byte progress, verifies Repository identity/size/Sum, and exposes typed HTTP failures.
- `artifact_digest.go`: binds declared Repository Info to Repository ZIP bytes through the shared Go-compatible h1 implementation.
- `artifact_digest_test.go`: specifies golden deterministic Sum acceptance and mismatch rejection.
- `client_test.go`: specifies strict Repository transport contracts, hostile response rejection, retries, and download progress.

## Architectural Boundary

This module owns the CLI's public Hub transport client and consumer-side artifact-integrity enforcement. Shared wire types, artifact algorithms, identity grammar, locale normalization, and version-selection rules belong to the Protocol workspace. It must not persist local installation state, infer installation targets, or expose human-oriented response parsing to the App.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
