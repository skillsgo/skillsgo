# Public Release Design

SkillsGo publishes the CLI and Hub from independent version tags while keeping their public contracts compatible through the shared Protocol module.

## Release Units

| Unit | Source | Tag | Artifacts |
| --- | --- | --- | --- |
| CLI | `cli/` and `protocol/` | `cli/vX.Y.Z` | Standalone archives for macOS arm64/amd64, Linux arm64/amd64, and Windows amd64, plus checksums |
| Hub | `hub/` and `protocol/` | `hub/vX.Y.Z` | Go release metadata and container image when enabled by the release workflow |

Tags are immutable. A release workflow must verify that the requested version matches its source metadata, build from the tagged commit, generate checksums, and fail before publication when validation is incomplete.

## CLI Contract

`scripts/build-cli-release.sh` is the canonical single-target build boundary. It builds with `GOWORK=off`, injects version and commit metadata, and produces deterministic archive layouts suitable for direct download and package-manager manifests.

Release candidates cover every supported `GOOS/GOARCH` pair in continuous integration. Published checksums are generated from the final archives rather than intermediate binaries.

## Hub Contract

The Hub release preserves the exported Runtime and HTTP contracts documented under `hub/`. An embedding application may compose the Runtime with its own community-data implementation without changing the reusable public module.

## Compatibility

Protocol changes that affect CLI and Hub interpretation require executable compatibility tests before either unit is tagged. Breaking public behavior requires an explicit versioning decision and an ADR under `docs/adr/`.

## Credentials

Release credentials are repository configuration, never source material. Workflows use least-privilege GitHub permissions and must not print tokens, signing material, production identifiers, or private operational configuration.
