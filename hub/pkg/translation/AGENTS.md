# Translation/
> F3 | Parent: `hub/AGENTS.md` | Workspace: `hub`

## Members

- `translator.go`, `translator_test.go`: OpenAI-compatible description translation client and network contract coverage.
- `worker.go`: executes one bounded, retryable candidate translation and persistence batch for River.
- `worker_test.go`: network-free task-handler persistence contract coverage.

## Architectural Boundary

This module owns presentation-only Repository and Skill description translation. Scheduling, retry, and multi-instance execution belong to `pkg/taskqueue` and River. It must not mutate artifacts, source metadata, README content, or installation data.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
