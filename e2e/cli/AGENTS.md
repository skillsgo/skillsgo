# CLI + Hub End-to-End Tests
> F2 Workspace Map | Parent: `/e2e/AGENTS.md` | Manifest: `go.mod`

This workspace owns black-box user-journey tests spanning the released CLI and Hub binaries.

## Workspace Identity

- Module: `github.com/skillsgo/skillsgo/e2e`
- Runtime: Go test controller plus one disposable Linux container per scenario
- Public seams: CLI process arguments and JSON output, Hub HTTP protocol, and user-visible filesystem state

## Members

- `Dockerfile`: builds the CLI and Hub Linux binaries into the reusable test image.
- `entrypoint.sh`: initializes the mounted sandbox and runs the Hub as the container foreground process.
- `git-fixtures.sh`: creates deterministic local Git remotes reached through the public Repository source path.
- `git-wrapper.sh`: delegates to system Git while adding deterministic latency for capacity-only source fixtures.
- `environment_test.go`: owns disposable container startup, the isolated bind mount, command execution, shared fixtures, and assertion helpers.
- `j01_*_test.go` through `j45_*_test.go`: each file owns exactly one numbered user-journey contract from `USER-JOURNEYS.md`; support code must remain outside these files.
- `USER-JOURNEYS.md`: prioritizes real cross-product user stories and their observable acceptance boundaries.

## Boundaries

- Tests must not import `cli/internal/**` or `hub/internal/**` packages.
- Every scenario must use its own container and `t.TempDir()` bind mount.
- Never mount the repository, the host home directory, or a real Agent directory into a scenario container.
- Assertions target stable JSON, HTTP, and filesystem contracts rather than human-oriented terminal copy.

## Commands

Run from this directory:

```bash
go test -v ./...
```

[PROTOCOL]: Update this map when workspace structure, ownership, commands, or boundaries change.
