# Registry Client Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `client.go`: resolves assessed Info and downloads Manifest/ZIP responses from a configured SkillsGo Registry.
- `artifact_digest.go`: recomputes the Registry-compatible normalized Content Digest from ZIP or extracted directories and binds Info to exact artifact files.
- `artifact_digest_test.go`: specifies golden deterministic digest acceptance and mismatch rejection.

## Architectural Boundary

This module owns the CLI's public Registry protocol client and artifact-integrity verification. It must not persist Store state, infer installation targets, or expose human-oriented response parsing to the App.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
