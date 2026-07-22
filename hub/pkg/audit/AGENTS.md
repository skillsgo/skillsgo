# Hub Artifact Audit Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `artifact.go`: consumes the shared Protocol one-pass normalized ZIP traversal while converting each visited file into an inspectable inventory, executable signals, and a deterministic risk assessment carrying the exact Sum returned by that traversal.
- `artifact_test.go`: specifies archive validation, duplicate rejection, golden Sums, assessment-to-artifact binding, real instruction extraction, file classification, truncation, and risk evidence.

## Architectural Boundary

This module owns Hub-specific deterministic inspection and risk evidence. Artifact format, limits, safe paths, normalized traversal, and Sum calculation belong to the Protocol workspace. It must not fetch sources, persist assessments, serialize HTTP responses, infer publisher trust, or inspect local installations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
