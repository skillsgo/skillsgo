# Workspace Persistence Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `files.go`: owns the editable `skillsgo.yaml` Workspace Manifest, atomic requirement/binding mutation, and nearest Workspace-root discovery.
- `file_lock.go`: provides bounded cross-process exclusion and stale-lock recovery shared by Workspace persistence writers.
- `workspace_sum.go`: owns the generated, integrity-only `skillsgo.sum` ledger, checksum verification, and locked crash-safe updates.
- `installed.go`: derives concrete managed installations from portable Workspace intent, immutable metadata, the Store, and current Agent paths.
- `*_test.go`: specifies pure persistence parsing plus behavior exercised through the CLI command seam.

## Architectural Boundary

This module owns portable Workspace declarations and integrity persistence. The Manifest records canonical direct requirements and desired Agents; the Workspace Sum records only verified immutable resource hashes. It must not fetch Hub resources, treat checksums as artifacts, persist absolute Agent paths, or use local Installation Receipts as portable restore intent.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
