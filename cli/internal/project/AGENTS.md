# Workspace Persistence Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `files.go`: owns the editable Go-like `skillsgo.mod` Workspace Manifest, its `[agent, ...]` require extension, atomic requirement/binding mutation, and nearest Workspace-root discovery.
- `installation_receipts.go`: atomically records and loads exact target-to-Store Installation Receipts together with Manifest and Workspace Sum installation/replacement commits, using a shared transaction lock and crash-recovery journal.
- `file_lock.go`: adapts gofrs/flock operating-system locks into bounded cross-process exclusion shared by Workspace persistence writers; process exit releases ownership without PID files or stale-lock heuristics.
- `workspace_sum.go`: owns the generated, integrity-only `skillsgo.sum` ledger, checksum verification, and locked crash-safe updates.
- `installed.go`: derives concrete managed installations from one locked, crash-recovered Manifest and Installation Receipt snapshot before reconciling the Store and current Agent paths.
- `*_test.go`: specifies pure persistence parsing plus behavior exercised through the CLI command seam.

## Architectural Boundary

This module owns portable Workspace declarations, integrity persistence, and the separate local target projection ledger. The Manifest records canonical direct requirements and desired Agents; the Workspace Sum records only verified immutable resource hashes; Installation Receipts record exact local paths and target states but never become portable restore intent. It must not fetch Hub resources, treat checksums as artifacts, or persist absolute Agent paths in the Manifest or Sum.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
