# Move the Desktop App and CLI Authority to OSS

## Status

Proposed design approved for implementation planning. The migration must preserve the current App behavior while making the public repository the only source and release authority for the desktop App and CLI.

## Context

The desktop App was added to `skillsgo-cloud` by commit `cd84f2d` as a large snapshot, then evolved there through App, desktop E2E, packaging, and release commits. The public repository already owns the authoritative CLI, Hub, and Protocol. Cloud currently consumes the CLI through the `third_party/skillsgo` submodule.

This creates two undesirable boundaries:

- The App source and its release lifecycle live in the private repository.
- The App builds a pinned CLI mirror instead of consuming the CLI in the same repository.

The target is an open-source desktop client repository with a single App/CLI source tree and an independently deployable Cloud service repository.

## Goals

- Move the complete Personal desktop App source, assets, tests, desktop E2E, build scripts, and release workflow to `skillsgo-oss`.
- Keep `skillsgo-oss/cli` as the only CLI implementation source.
- Build the bundled CLI directly from the same OSS checkout as the App.
- Preserve App history from Cloud as far as practical instead of representing the move as a synthetic revert.
- Let OSS independently test, build, package, and publish the App without checking out Cloud.
- Remove App source, App E2E, the CLI submodule, and App release ownership from Cloud.
- Keep Cloud private server, Web, production composition, persistence, provider ingestion, operations, and secrets private.
- Publish only generic public contracts and configurable release seams; never move private production topology or credentials into OSS.

## Non-Goals

- Moving Cloud Server, ranking persistence, provider synchronization, database schemas, deployment topology, or private operational documentation.
- Reimplementing the Hub or CLI inside the App.
- Maintaining a second App mirror in Cloud after the migration.
- Preserving Cloud's private ranking implementation as a public client dependency.
- Introducing a compatibility layer for the old Cloud checkout after ownership has moved.

## Target Ownership

### OSS owns

- `app/`: Flutter desktop App and Personal product experience.
- `cli/`: Go CLI and local Skill execution engine.
- `protocol/`: shared executable contracts.
- App unit/widget/integration tests and App desktop E2E orchestration.
- App platform runners, bundled-CLI packaging, candidate packaging, update rehearsal, checksums, and public App release workflow.
- Public App documentation, App-facing ADRs, and generic release configuration.

### Cloud owns

- Cloud Server and its private persistence and projections.
- Official production Hub composition and private community-data implementation.
- Web, authentication bridge, image proxy, deployment, operations, and production secrets.
- Consumption of released public artifacts where required, but not their source or build authority.

## Repository Shape

The final public repository will contain:

```text
skillsgo-oss/
├── app/
├── cli/
├── hub/
├── protocol/
├── e2e/
│   ├── cli/
│   └── app/
├── scripts/
└── .github/workflows/
    ├── ci.yml
    ├── cli-release.yml
    ├── hub-release.yml
    └── app-release.yml
```

The final Cloud repository will not contain `app/`, `e2e/app/`, `third_party/skillsgo/`, or an App release workflow.

## Migration Method

This is a cross-repository history import followed by a Cloud ownership cleanup, not a single `git revert`.

1. Record the selected Cloud App migration point and the current dirty-worktree inventories in both repositories.
2. Extract the App history and App-owned supporting files from Cloud into an import branch or temporary filtered repository.
3. Import the extracted history into OSS without overwriting existing user changes.
4. Reconcile App paths and documentation with the OSS monorepo layout.
5. Connect App packaging to the same-repository `cli/` module.
6. Move App CI, release, E2E, and packaging entry points into OSS.
7. Run OSS validation and release-contract checks independently.
8. Remove Cloud App ownership in one explicit cleanup change after OSS is green.

The migration must not use destructive Git commands, reset either worktree, or stage unrelated user changes.

## App and CLI Boundary

The App continues to use the bundled CLI as its only Hub and local business boundary. The behavior remains:

```text
Flutter App -> bundled CLI machine protocol -> public Hub or local filesystem
```

The source/build relationship changes to:

```text
skillsgo-oss/app -> skillsgo-oss/cli -> skillsgo-oss/protocol
skillsgo-oss/cli -> skillsgo-oss/protocol
```

The macOS, Windows, and Linux packaging bridges must resolve the CLI from the OSS checkout. The App must continue to validate the startup handshake, App protocol version, target OS, and App/CLI version contract.

## Public Capability Audit

Every moved App source file, asset, fixture, document, and workflow must be audited before publication.

- Cloud database names, provider details, production identifiers, private URLs, credentials, and operational instructions must not enter OSS.
- Fonts, logos, icons, backgrounds, vendored UI code, and generated assets require license/attribution verification.
- Public App behavior may depend only on public Hub, CLI, and Protocol contracts, plus configurable origins and release feeds.
- Existing ranking, trending, and hot discovery code must be classified before migration:
  - If the behavior is already a public Hub contract, keep it under the public contract and document it in OSS.
  - If it depends on a Cloud-only ranking response, remove the hard dependency or replace it with an explicitly public optional capability.
  - Cloud private persistence and provider ingestion must never be exposed through copied implementation details.
- Personal App behavior remains accountless and local-first; team, billing, approval, audit, and cloud synchronization remain out of scope.

## Release Design

OSS will own App release artifacts and workflow structure. The public workflow may define build matrices, artifact naming, checksums, attestations, and configurable update-feed inputs. Signing identities, publishing credentials, production feed values, and repository environments remain GitHub configuration, never source files.

Release units remain independently versioned:

```text
cli/vX.Y.Z
hub/vX.Y.Z
app/vX.Y.Z
```

The App release must build architecture-specific macOS artifacts and must not treat a universal local Flutter output as the production release artifact. Existing Linux and Windows packaging behavior remains covered by the migration validation.

## Verification Gates

### OSS gates

- `flutter analyze` and `flutter test` from `app/`.
- App bundled-CLI smoke tests and the smallest deterministic App E2E journeys.
- App release-contract and update-rehearsal tests.
- `go test ./...` from `cli/`, `hub/`, and `protocol/`.
- Existing CLI E2E and root validation.
- App builds without a Cloud checkout or submodule.

### Cloud gates

- Server, Web, authentication bridge, image-worker, and operations tests continue to pass.
- Cloud no longer contains App source, App E2E, CLI submodule, or App release entry points.
- Cloud documentation and Makefile no longer claim App source or release ownership.

### Boundary gates

- No private production facts or secrets are present in moved files.
- The moved App has one public source of truth and one CLI implementation source.
- The App can use official or self-hosted public Hub Origins through the existing public protocol.
- Existing uncommitted user changes remain untouched and unstaged.

## Rollback

Before each destructive ownership change, preserve the source commit IDs and produce a file-level manifest. If validation fails, revert only the migration commits created by this work; do not reset either repository or discard unrelated changes. The Cloud source remains recoverable from its pre-cleanup commit until OSS validation and release rehearsal complete.

## Open Decisions During Execution

- Exact App E2E and release files that are App-owned versus Cloud-only orchestration adapters.
- Whether ranking/trending/hot behavior is fully public Hub behavior or requires removal/optionalization.
- Final App tag and artifact naming details where they conflict with existing Cloud release conventions.
- Asset licensing exceptions discovered during the file-by-file audit.

[PROTOCOL]: Update this document when the approved migration design changes.
