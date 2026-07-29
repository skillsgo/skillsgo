# Translation/
> F3 | Parent: `hub/AGENTS.md` | Workspace: `hub`

## Members

- `translator.go`, `translator_test.go`: OpenAI-compatible description translation client, conservative model-wrapper normalization, one bounded model-format correction, and network contract coverage.
- `language.go`, `language_test.go`: Goldmark paragraph-whitelist extraction, cached Lingua low multilingual analysis, and conservative target gating.
- `protection.go`, `protection_test.go`: deterministic technical-span placeholders, harmless tag-format normalization, and validated byte-identical restoration.
- `document.go`, `document_test.go`: display-only Markdown-body translation and structural validation.
- `document_worker.go`, `document_worker_test.go`: discover bounded missing/stale document-localization identities and execute one idempotent document-plus-locale operation with content validation and sidecar reuse.
- `worker.go`, `worker_test.go`: discover bounded missing/stale description-localization identities and execute one idempotent description-plus-locale operation.
- `error.go`, `error_test.go`: classify deterministic source/model-validation and non-retryable provider failures as permanent without importing task transport.

## Architectural Boundary

This module owns presentation-only Repository and Skill description translation plus display-only Skill document translation. Scheduling, retry, and multi-instance execution belong to `pkg/taskqueue` and River. It must not mutate artifacts, source metadata, README content, or installation data.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
