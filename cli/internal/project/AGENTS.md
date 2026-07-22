# Workspace Persistence Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `files.go`: owns atomic Workspace requirement/binding mutation, deterministic Manifest publication, and nearest Workspace-root discovery.
- `manifest_parser.go`: owns the closed SkillsGo-native `require ID version [agents] [mode]` grammar, canonical identity/version validation, comments, and default-symlink semantics.
- `installation_receipts.go`: atomically records and loads exact target-to-Store Installation Receipts together with Manifest and Workspace Sum installation/replacement commits, using a shared transaction lock and crash-recovery journal.
- `file_lock.go`: adapts gofrs/flock operating-system locks into bounded cross-process exclusion shared by Workspace persistence writers; process exit releases ownership without PID files or stale-lock heuristics.
- `workspace_sum.go`: owns the generated, integrity-only `skillsgo.sum` ledger, checksum verification, and locked crash-safe updates.
- `workspace_yaml.go`: owns strict `skillsgo.yaml` Repository dependency intent, strict `skillsgo.lock` Repository integrity, deterministic normalization, and their paired crash-recoverable publication.
- `installed.go`: derives concrete managed installations from one locked, crash-recovered Manifest and Installation Receipt snapshot before reconciling the Store and current Agent paths.
- `*_test.go`: specifies pure persistence parsing plus behavior exercised through the CLI command seam.

## Architectural Boundary

This module owns portable Workspace declarations, Repository integrity persistence, and the separate local target projection ledger. `skillsgo.yaml` records canonical Repository requirements, selected member paths, and desired Agents; `skillsgo.lock` records only immutable Repository versions and Sums. Migration-era Manifest/Sum/Receipt code remains isolated until its consumers are replaced. This module must not fetch Hub resources, treat checksums as artifacts, or persist absolute Agent paths in portable state.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
