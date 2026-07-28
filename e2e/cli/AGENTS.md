# CLI + Hub End-to-End Tests
> F2 Workspace Map | Parent: `/e2e/AGENTS.md` | Manifest: `go.mod`

This workspace owns black-box user-journey tests spanning the released CLI and Hub binaries.

## Workspace Identity

- Package: `github.com/skillsgo/skillsgo/e2e`
- Runtime: Go test controller plus one reusable CLI/Hub/Cloud-Mock container and one PostgreSQL container shared by the serial suite; each Journey starts a Hub process against its own PostgreSQL schema, rebuilt local directories, and restored Git fixtures, while local runs build the image on demand and CI restores BuildKit layers
- Test reporter: workspace-pinned `gotestsum`, which streams journey events during execution and retains the complete-run failure summary
- Public seams: CLI process arguments and JSON output, Hub HTTP protocol, and user-visible filesystem state

## Members

- `Dockerfile`: builds the CLI, Hub, and test-only Cloud mock Linux binaries into the reusable test image.
- `entrypoint.sh`: initializes the mounted suite sandbox and Git baseline, starts the suite-scoped test-only Cloud process, and keeps the reusable runtime container available for Journey-scoped Hub processes.
- `cloud-mock/main.go`: exposes the public Cloud Mock in a separate process plus an E2E-only event-observation endpoint.
- `git-fixtures.sh`: creates deterministic local Git remotes reached through the public Repository source path.
- `git-wrapper.sh`: delegates to system Git while explicitly routing the fixture host to local bare repositories and adding deterministic latency for capacity-only source fixtures.
- `environment_test.go`: owns suite-scoped runtime/PostgreSQL startup and whole-container cleanup, the private network and bind mount, serial Journey Hub/schema/filesystem/Git isolation, command execution, Repository artifact lookup, and assertion helpers.
- `repository_fixture_test.go`: provides behavior-level mutable Repository fixture operations so journeys request source publication/ref changes without embedding Git choreography.
- `adoption_fixture_test.go`: provides typed stdin JSON adoption requests/reports and a released-CLI black-box runner for External adoption journeys.
- `j01_*_test.go` through `j57_*_test.go`: each file owns exactly one numbered user-journey contract from `USER-JOURNEYS.md`; support code must remain outside these files.
- `USER-JOURNEYS.md`: prioritizes real cross-product user stories and their observable acceptance boundaries.

## Boundaries

- Tests must not import `cli/internal/**` or `hub/internal/**` packages.
- The suite must use exactly one CLI/Hub container and one PostgreSQL container, run Journeys serially, give each Journey a fresh PostgreSQL schema and Hub process, restore the fixed Git baseline, and rebuild every CLI-local mutable directory before the Journey begins. Journey schemas are retained until the disposable PostgreSQL container is destroyed after the complete suite.
- Never mount the repository, the host home directory, or a real Agent directory into the suite container.
- Assertions target stable JSON, HTTP, and filesystem contracts rather than human-oriented terminal copy.

## Commands

Run from this directory:

```bash
GOWORK=off go tool gotestsum --format standard-verbose -- -count=1 -timeout=15m ./...
```

[PROTOCOL]: Update this map when workspace structure, ownership, commands, or boundaries change.
