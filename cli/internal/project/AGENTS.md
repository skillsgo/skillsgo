# Workspace Persistence Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `file_lock.go`: adapts gofrs/flock operating-system locks into bounded cross-process exclusion shared by Workspace persistence writers; process exit releases ownership without PID files or stale-lock heuristics.
- `workspace_yaml.go`: owns strict `skills.yaml` Module dependency intent, strict `skills-lock.yaml` integrity, Global Declaration/State roots, nearest Workspace discovery, atomic paired loading with journal recovery, exact pair validation, deterministic normalization, and paired crash-recoverable publication.
- `metadata_transaction.go`: owns exact YAML/Lock snapshots, rollback journal recovery, and atomic paired publication under the workspace metadata lock.
- `*_test.go`: specifies pure persistence parsing plus behavior exercised through the CLI command seam.

## Architectural Boundary

This module owns portable Workspace and Global declarations plus Module integrity persistence. `skills.yaml` records canonical Module requirements, selected member paths, and desired Agents; `skills-lock.yaml` records only immutable Module versions and Sums. It must not fetch Hub resources, treat checksums as artifacts, persist absolute Agent paths, or maintain a parallel Receipt ledger.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
