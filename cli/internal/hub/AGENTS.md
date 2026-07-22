# Hub Client Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `client.go`: delegates version selectors to the Hub `/mod` surface, consumes shared Protocol Repository/Skill Info and product API DTOs, forwards optional presentation locales for discovery/detail, validates strict provider-neutral `/api/v1` reads, downloads verified ZIP responses with optional byte progress, resolves exact content matches, and exposes typed HTTP failures from a configured SkillsGo Hub.
- `artifact_digest.go`: binds declared Info to ZIP or extracted-directory bytes through the shared Protocol h1 Sum implementation.
- `artifact_digest_test.go`: specifies golden deterministic Sum acceptance and mismatch rejection.
- `client_test.go`: specifies source-hint request encoding and strict content-match response validation.

## Architectural Boundary

This module owns the CLI's public Hub transport client and consumer-side artifact-integrity enforcement. Shared wire types, artifact algorithms, identity grammar, locale normalization, and version-selection compatibility rules belong to the Protocol workspace. It must not persist Store state, infer installation targets, or expose human-oriented response parsing to the App.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
