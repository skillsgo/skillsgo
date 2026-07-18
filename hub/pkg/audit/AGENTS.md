# Hub Artifact Audit Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `artifact.go`: converts one immutable Skill ZIP into a bounded duplicate-safe file inventory, normalized Content Digest, inspectable text content, executable signals, and a deterministic risk assessment carrying the exact Artifact Digest it assessed.
- `artifact_test.go`: specifies archive validation, duplicate rejection, golden Content Digests, assessment-to-artifact binding, real instruction extraction, file classification, truncation, and risk evidence.

## Architectural Boundary

This module owns deterministic inspection of immutable artifact bytes. It must not fetch sources, persist assessments, serialize HTTP responses, infer publisher trust, or inspect local installations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
