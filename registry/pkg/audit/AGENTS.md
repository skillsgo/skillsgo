# Registry Artifact Audit Module
> F3 | Parent: `/registry/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/registry`

## Members

- `artifact.go`: converts one immutable Skill ZIP into a bounded duplicate-safe file inventory, normalized Content Digest, inspectable text content, executable signals, and a deterministic risk assessment.
- `artifact_test.go`: specifies archive validation, duplicate rejection, golden Content Digests, real instruction extraction, file classification, truncation, and risk evidence.

## Architectural Boundary

This module owns deterministic inspection of immutable artifact bytes. It must not fetch sources, persist assessments, serialize HTTP responses, infer publisher trust, or inspect local installations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
