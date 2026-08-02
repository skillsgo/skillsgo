# ADR-0022: Publish Authenticated Standalone CLI Releases

- Status: Accepted
- Date: 2026-08-02

## Context

The SkillsGo CLI can be built inside the repository and bundled with the desktop App, but terminal users also need independently versioned binaries. GitHub-only update discovery is unreliable for some users, package-manager ownership differs by installation source, and replacing an executable from unauthenticated mutable metadata would create a high-impact supply-chain boundary.

The existing App release control plane already establishes useful publication discipline: tag-only production releases, `main` reachability, architecture-specific builds, immutable version objects, public read-back, and mutable feed publication last. The CLI is not a Velopack application and must not inherit its package or lifecycle protocol.

## Decision

1. Standalone CLI releases use `cli/vX.Y.Z` tags and five Tier-1 archives: macOS arm64/amd64, Linux arm64/amd64, and Windows amd64.
2. One repository build contract compiles every archive with `GOWORK=off` and injects CLI version, distribution, commit, and build time. App bundles additionally identify themselves as `bundled` and carry an App bundle version.
3. The public update Origin is fixed at `https://cdn.skillsgo.ai`. Runtime environment variables cannot replace this trust boundary.
4. Every version publishes immutable archives, checksums, SBOMs, `manifest.json`, and a raw Ed25519 `manifest.sig` under `/cli/versions/<version>/`.
5. The OSS release workflow creates the immutable GitHub Release and an unsigned provider-neutral Manifest payload. An embedding publisher signs that exact payload, uploads immutable objects, reads them back through its public Origin, and publishes `/cli/stable/manifest.*` last.
6. The CLI embeds the Manifest verification public key, verifies the signature before JSON decoding, validates canonical SemVer and same-Origin immutable artifact URLs, and bounds every metadata response.
7. The first self-update capability is authenticated checking only. Package-manager and bundled distributions receive their owning upgrade command. Direct executable replacement remains closed until archive extraction, atomic replacement, rollback, Windows helper behavior, and end-to-end interruption tests are implemented and reviewed together.
8. GitHub Release is the public archive and fallback download location. Installed clients do not depend on the GitHub Release API.

## Consequences

- A standalone CLI can be built and audited independently of the App without duplicating product code.
- CDN compromise alone cannot forge trusted release metadata or redirect clients to another Origin, while signing-key compromise requires key rotation and a client trust-root release.
- The embedding publisher must fail when signing, immutable upload, or public read-back is unavailable rather than degrading to GitHub-only update discovery.
- Homebrew, WinGet, npm, npx, and `go install` integrations may consume the same official archive bytes or direct users to their native upgrade mechanism, but their packaging automation remains a subsequent delivery phase.
- The bundled App CLI continues to update only with the App and cannot invoke executable replacement.
