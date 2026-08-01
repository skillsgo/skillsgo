# Translation/
> F3 | Parent: `hub/AGENTS.md` | Workspace: `hub`

## Members

- `translator.go`, `translator_test.go`: OpenAI-compatible description translation client, conservative model-wrapper normalization, one bounded model-format correction, and network contract coverage.
- `language.go`, `language_test.go`: Goldmark paragraph-whitelist extraction, cached Lingua low multilingual analysis, and conservative target gating.
- `protection.go`, `protection_test.go`: deterministic technical-span placeholders, harmless tag-format normalization, and validated byte-identical restoration.
- `document.go`, `document_test.go`: display-only Markdown-body translation and structural validation.
- `document_worker.go`, `document_worker_test.go`: consume one Catalog-fair, current-first cross-locale batch of missing/stale document-localization identities and execute one idempotent document-plus-locale operation with content validation and sidecar reuse.
- `worker.go`, `worker_test.go`: discover bounded missing/stale description-localization identities and execute one idempotent description-plus-locale operation.
- `error.go`, `error_test.go`: classify deterministic document validation, exhausted model-format correction, and non-retryable provider failures as permanent, while preserving provider-payment and transient infrastructure failures as retryable without importing task transport.
- `schedule.go`, `schedule_test.go`: parse operator-defined time-zone-aware provider-cost admission windows and calculate the next allowed translation instant without owning task persistence or execution.

## Architectural Boundary

This module owns presentation-only Repository and Skill description translation, display-only Skill document translation, and pure provider-cost admission policy. Persistent scheduling, snooze, retry, and multi-instance execution belong to `pkg/taskqueue` and River. It must not mutate artifacts, source metadata, README content, or installation data.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
