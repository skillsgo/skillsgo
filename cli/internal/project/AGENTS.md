# Workspace Persistence Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `workspace_yaml.go`: owns strict `skills.yaml` Package dependency intent, strict `skills-lock.yaml` integrity, Global Declaration/State roots, nearest Workspace discovery, paired loading with journal recovery, exact pair validation, deterministic normalization, and paired crash-recoverable publication.
- `metadata_transaction.go`: owns exact YAML/Lock snapshots, rollback journal recovery, and atomic paired publication without persistent lock artifacts.
- `*_test.go`: specifies pure persistence parsing plus behavior exercised through the CLI command seam.

## Architectural Boundary

This module owns portable Workspace and Global declarations plus Package integrity persistence. `skills.yaml` records canonical Package requirements, selected member paths, and desired Agents; `skills-lock.yaml` records only immutable Package versions and Sums. It must not fetch Hub resources, treat checksums as artifacts, persist absolute Agent paths, or maintain a parallel Receipt ledger.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
