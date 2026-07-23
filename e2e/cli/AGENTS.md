# CLI + Hub End-to-End Tests
> F2 Workspace Map | Parent: `/e2e/AGENTS.md` | Manifest: `go.mod`

This workspace owns black-box user-journey tests spanning the released CLI and Hub binaries.

## Workspace Identity

- Module: `github.com/skillsgo/skillsgo/e2e`
- Runtime: Go test controller plus disposable Hub/CLI and PostgreSQL containers on one private network per scenario
- Public seams: CLI process arguments and JSON output, Hub HTTP protocol, and user-visible filesystem state

## Members

- `Dockerfile`: builds the CLI, Hub, and test-only Cloud mock Linux binaries into the reusable test image.
- `entrypoint.sh`: initializes the mounted sandbox, optionally starts the test-only Cloud process, and runs the Hub as the container foreground process.
- `cloud-mock/main.go`: exposes the public Cloud Mock in a separate process plus an E2E-only event-observation endpoint.
- `git-fixtures.sh`: creates deterministic local Git remotes reached through the public Repository source path.
- `git-wrapper.sh`: delegates to system Git while explicitly routing the fixture host to local bare repositories and adding deterministic latency for capacity-only source fixtures.
- `environment_test.go`: owns disposable application/PostgreSQL container startup, their private network, the isolated bind mount, command execution, shared fixtures, Repository artifact lookup, and assertion helpers.
- `repository_fixture_test.go`: provides behavior-level mutable Repository fixture operations so journeys request source publication/ref changes without embedding Git choreography.
- `j01_*_test.go` through `j48_*_test.go`: each file owns exactly one numbered user-journey contract from `USER-JOURNEYS.md`; support code must remain outside these files.
- `USER-JOURNEYS.md`: prioritizes real cross-product user stories and their observable acceptance boundaries.

## Boundaries

- Tests must not import `cli/internal/**` or `hub/internal/**` packages.
- Every scenario must use its own container and `t.TempDir()` bind mount.
- Never mount the repository, the host home directory, or a real Agent directory into a scenario container.
- Assertions target stable JSON, HTTP, and filesystem contracts rather than human-oriented terminal copy.

## Commands

Run from this directory:

```bash
GOWORK=off go test -v -count=1 ./...
```

[PROTOCOL]: Update this map when workspace structure, ownership, commands, or boundaries change.
