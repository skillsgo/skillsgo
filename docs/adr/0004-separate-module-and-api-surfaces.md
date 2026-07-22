# ADR 0004: Separate Module and API Surfaces

## Status

Accepted.

## Context

SkillsGo exposes two different public HTTP models: a Go-proxy-inspired immutable artifact protocol and a conventional product API for search, ranking, metadata, and events. Serving artifact coordinates at the Hub root while serving product resources under `/v1` made the boundary implicit. The local portable declaration also used YAML despite already modeling Go-like direct requirements and an integrity-only sum file.

## Decision

- The immutable artifact protocol is rooted at `/mod/{coordinate}` and exposes `@v/list`, `@head`, `@release`, `@v/{version}.info`, and `@v/{version}.zip` below that coordinate. The ambiguous `@latest` spelling is rejected.
- Product HTTP resources are rooted at `/api/v1`.
- The portable declaration is `skillsgo.mod`; `skillsgo.sum` remains the integrity ledger.
- `skillsgo.mod` accepts a closed SkillsGo-native `require ID version [agents] [mode]` line and block grammar. Mode defaults to `symlink`; canonical output emits only the non-default `copy` mode:

  ```text
  require (
      github.com/owner/repo v1.2.3 [codex, claude-code] copy
      github.com/owner/repo/-/skills/design v2.0.0 [zed]
  )
  ```

- Artifact versions do not inherit Go import-path major-version rules. A Skill or Repository coordinate may therefore use `v2.0.0` without a `/v2` path suffix.
- The Manifest parser does not use Go directive semantics. It validates canonical SkillsGo IDs and immutable versions directly while preserving ordinary human comments.
- This is a breaking migration. The old root artifact routes, `/v1` API routes, and `skillsgo.yaml` declaration are not compatibility aliases.

## Consequences

Module transport, product APIs, and local intent now have visible, stable boundaries. CLI and App releases must migrate atomically with the Hub. A `skillsgo.mod` file contains portable desired Agent targets, so restoring on another machine can recreate target directories and projections while `skillsgo.sum` verifies immutable bytes.
