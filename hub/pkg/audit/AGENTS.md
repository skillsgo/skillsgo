# Hub Artifact Audit Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `artifact.go`: uses shared Protocol archive limits, paths, entry reads, and digest framing while converting one immutable Skill ZIP into an inspectable file inventory, executable signals, and a deterministic risk assessment carrying the exact Artifact Digest it assessed.
- `artifact_test.go`: specifies archive validation, duplicate rejection, golden Content Digests, assessment-to-artifact binding, real instruction extraction, file classification, truncation, and risk evidence.

## Architectural Boundary

This module owns Hub-specific deterministic inspection and risk evidence. Artifact format, limits, safe paths, and Content Digest framing belong to the Protocol workspace. It must not fetch sources, persist assessments, serialize HTTP responses, infer publisher trust, or inspect local installations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
