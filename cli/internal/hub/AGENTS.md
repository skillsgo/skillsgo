# Hub Client Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `client.go`: delegates version selectors to the Hub, consumes flat self-contained Repository/Skill Info, reads product metadata for App-ready cards, downloads verified ZIP responses with optional byte progress, resolves exact content matches, and exposes typed HTTP failures from a configured SkillsGo Hub.
- `artifact_digest.go`: recomputes the Hub-compatible normalized Content Digest from ZIP or extracted directories and binds Info to exact artifact files.
- `artifact_digest_test.go`: specifies golden deterministic digest acceptance and mismatch rejection.
- `client_test.go`: specifies source-hint request encoding and strict content-match response validation.

## Architectural Boundary

This module owns the CLI's public Hub protocol client and artifact-integrity verification. It must not implement SemVer selection, persist Store state, infer installation targets, or expose human-oriented response parsing to the App.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
