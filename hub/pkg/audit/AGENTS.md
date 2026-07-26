# Hub Artifact Audit Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `artifact.go`: consumes the shared Protocol one-pass Repository ZIP traversal while projecting one selected Skill member into an inspectable file inventory, executable signals, and the exact Module Sum returned by that traversal.
- `artifact_test.go`: specifies archive validation, duplicate rejection, golden Sums, real instruction extraction, file classification, truncation, and executable-file detection.

## Architectural Boundary

This module owns Hub-specific deterministic file inspection and executable signals. Artifact format, limits, safe paths, normalized traversal, and Sum calculation belong to the Protocol workspace. It must not fetch sources, persist assessments, serialize HTTP responses, infer publisher trust, or inspect local installations.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
