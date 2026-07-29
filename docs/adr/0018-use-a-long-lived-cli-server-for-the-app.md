# Use a Long-Lived CLI Server for the App

## Status

Accepted.

## Context

The desktop App historically started one bundled CLI process for every business operation. The boundary kept business behavior in Go, but each Hub read also paid process startup, DNS lookup, TCP connection, and TLS negotiation costs. The Go HTTP transport could not retain idle connections after the short-lived CLI process exited.

The App and CLI are released as one bundle and already negotiate an exact `appProtocolVersion`. Backward compatibility between an updated App and an older bundled CLI is therefore neither required nor desirable.

## Decision

The App performs startup compatibility detection with the existing one-shot `version --output json` command, then lazily starts one bundled `skillsgo server --stdio` process for all business operations.

The server uses a versioned NDJSON envelope. Each request contains a correlation ID, structured argument array, optional stdin document, and optional stdout streaming preference. Correlated stdout event frames preserve mutation progress, and one final response contains the same ID, exit code, complete stdout, and stderr. Ordinary command machine contracts remain unchanged inside these frames.

The server executes requests sequentially. This preserves the CLI's existing local transaction and global configuration assumptions while allowing multiple App callers to submit correlated requests. A request-level command failure is returned without terminating the server. A malformed protocol request is rejected without terminating the server.

The App recreates a dead server for the next operation. It does not automatically replay the interrupted operation because mutation commands may already have committed state before a transport failure. Explicit user retry and the CLI's existing reconciliation behavior remain the recovery boundary.

The terminal CLI remains one-shot. The long-lived server is an App transport, not a second business API.

`appProtocolVersion` 17 requires this server capability.

## Consequences

- Go's shared default HTTP transport can retain Hub connections across App operations, eliminating repeated DNS, TCP, and TLS setup on the hot path.
- CLI process startup is removed from all operations after the initial session creation.
- Sequential execution provides correctness but may queue concurrent App operations; measured demand must justify any future read concurrency model.
- Correlated stdout event frames preserve the existing live mutation-progress behavior while the final frame retains the complete command output for ordinary response decoding.
- Server crashes have an explicit non-replay recovery policy and do not leave the App permanently bound to a dead process.

## Validation

The implementation is covered at the CLI command seam for repeated requests, stdin forwarding, command failure isolation, and malformed-request recovery. App contract tests cover session reuse and replacement after process death. Production-Hub measurements are recorded in `docs/research/cli-server-performance-benchmark.md`.
