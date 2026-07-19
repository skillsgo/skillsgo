# Translation/
> F3 | Parent: `hub/AGENTS.md` | Workspace: `hub`

## Members

- `translator.go`: OpenAI-compatible description translation client.
- `worker.go`: single-process periodic candidate translation and persistence loop.
- `worker_test.go`: network-free worker persistence contract coverage.

## Architectural Boundary

This module owns presentation-only Repository and Skill description translation. It must not mutate artifacts, source metadata, README content, or installation data.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
