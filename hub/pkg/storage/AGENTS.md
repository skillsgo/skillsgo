# Immutable Artifact Storage Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `backend.go`, `getter.go`, `saver.go`, `lister.go`, `deleter.go`, and `cataloger.go`: define the backend-neutral artifact storage capabilities.
- `immutable.go`, `immutable_test.go`: define bounded `PutIfAbsent`, identical-content idempotency, immutable conflict detection, Skill-content delegation, and the process-local fallback used only when a backend has no stronger native implementation.
- `skill_content.go`: defines bounded, digest-validated, content-addressed source `SKILL.md` and display-only `SKILL.{lang}.md` objects shared across Package Versions and forks.
- `fs/`: persists Info and ZIP pairs through filesystem-native create-only publication and verifies existing bytes under cross-process races.
- `gcp/`, `s3/`, and `azureblob/`: adapt provider-native conditional object creation to the immutable coordinate contract and run compliance tests against fake-gcs-server, LocalStack, and Azurite respectively; S3 also serves as the shared transport for first-class Cloudflare R2 configuration and persists source and localized per-Skill Markdown sidecars.
- `mem/`: provides disposable in-memory storage for tests and development.
- `artifact/` and `compliance/`: provide Repository artifact adapters and reusable backend behavior tests.

## Architectural Boundary

This module owns byte persistence and immutable coordinate collision behavior. Repository publication remains owned by the Hub service and Catalog transaction, while ZIP structure and Sum rules belong to the shared Protocol artifact package. A storage backend must never overwrite an existing Package coordinate or content digest with different Info, ZIP, source Markdown, or localized Markdown bytes; implementation-specific retries, reservations, and conditional requests must preserve identical-content idempotency. Source Markdown uses `skillsmd/{digest}/SKILL.md`; localized Markdown uses `skillsmd/{digest}/{promptVersion}/SKILL.{lang}.md`.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
