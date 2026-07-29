# Artifact Object Store Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `backend.go` and `git_repository.go`: define the complete backend-neutral static Git Artifact Repository capability.
- `skill_content.go`: defines bounded, digest-validated, content-addressed source `SKILL.md` and display-only `SKILL.{lang}.md` objects shared across Package Versions and forks.
- `fs/`: persists Skill content and complete static Git repositories through filesystem-native operations.
- `gcp/`, `s3/`, and `azureblob/`: implement the same Git Repository and Skill-content contracts over GCS, S3/R2, and Azure Blob; immutable Git objects are reused while mutable dumb-HTTP discovery files are refreshed.
- `mem/`: provides disposable in-memory storage for tests and development.
- `compliance/`: provides reusable behavior tests for both required storage capabilities.

## Architectural Boundary

This module owns only Artifact bytes. Catalog owns Package Versions, membership, and Package Info. Every backend must implement both static bare-Git repository replication and content-addressed Skill Markdown persistence; ZIPs, version directories, and metadata listing are not storage concerns. A backend must never overwrite a content-addressed object with different bytes. Source Markdown uses `skillsmd/{digest}/SKILL.md`; localized Markdown uses `skillsmd/{digest}/{promptVersion}/SKILL.{lang}.md`.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
