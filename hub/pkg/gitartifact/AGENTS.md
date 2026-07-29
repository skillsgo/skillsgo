# Git Artifact Repository Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `repository.go`, `repository_test.go`: author deterministic parentless Package Artifact commits and immutable Version tags in standard bare Git repositories, then verify exact restoration over static dumb HTTP.
- `pack.go`: encode only newly written loose objects into self-contained incremental Git Packs, remove their loose copies, and periodically compact all reachable objects into one base Pack.
- `real_repository_benchmark_test.go`: opt-in allocation, wall-time, and Pack-size benchmarks for initial and incremental publication against the maintained five-repository local corpus; ordinary CI skips it when the corpus environment variable is absent.

## Architectural Boundary

This module owns the standard Git encoding of an already validated Package Artifact tree. Source resolution and safety filtering belong to `pkg/skill`; R2/filesystem replication belongs to `pkg/storage`; Package metadata and publication visibility belong to Catalog and Hub actions. It must never mirror upstream history or infer Skill membership.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
