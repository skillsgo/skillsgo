# Translation/
> F3 | Parent: `hub/AGENTS.md` | Workspace: `hub`

## Members

- `translator.go`, `translator_test.go`: OpenAI-compatible description translation client and network contract coverage.
- `language.go`, `language_test.go`: Goldmark paragraph-whitelist extraction, cached Lingua low multilingual analysis, and conservative target gating.
- `protection.go`, `protection_test.go`: deterministic technical-span placeholders and strict byte-identical restoration.
- `document.go`, `document_test.go`: display-only Markdown-body translation and structural validation.
- `document_worker.go`, `document_worker_test.go`: groups document work by source digest, analyzes and reads each source once, translates missing languages consecutively, and persists content-addressed results.
- `worker.go`: groups description work by source digest and executes one bounded, retryable multi-language batch for River.
- `worker_test.go`: network-free task-handler persistence contract coverage.

## Architectural Boundary

This module owns presentation-only Repository and Skill description translation plus display-only Skill document translation. Scheduling, retry, and multi-instance execution belong to `pkg/taskqueue` and River. It must not mutate artifacts, source metadata, README content, or installation data.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
