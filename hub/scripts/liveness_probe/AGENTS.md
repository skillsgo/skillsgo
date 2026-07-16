# Hub Liveness Probe

> F2 Workspace Map | Parent: `/hub/AGENTS.md` | Manifest: `go.mod`

This nested Go module builds the small Hub liveness probe used by operational tooling.

## Workspace Identity

- Module: `liveness_probe`
- Entry point: `main.go`
- Responsibility: verify that a configured Hub endpoint responds as expected.

## Commands

Run from `hub/scripts/liveness_probe/`:

```bash
gofmt -w main.go
go test ./...
go build .
```

## Member Map

| File | Responsibility |
| --- | --- |
| `main.go` | Probe process behavior and exit status. |
| `go.mod` | Independent utility-module declaration. |

## Boundaries

- Keep this workspace small and operationally focused.
- Do not move Hub runtime logic or public protocol implementation into the probe.
- A protocol or environment-variable change must stay aligned with the Hub service it probes.

## GEB Maintenance

- Add or update the F4 header in `main.go` when it is touched.
- The module manifest is exempt from an F4 comment header.

```text
// [INPUT]: Hub endpoint configuration and standard-library networking facilities.
// [OUTPUT]: A process exit status that reports Hub liveness.
// [POS]: Operational liveness-probe entry point for the Hub workspace.
// [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
```

[PROTOCOL]: Update this map when the probe contract, members, commands, or parent Hub assumptions change.
