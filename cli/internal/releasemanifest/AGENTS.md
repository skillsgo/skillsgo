# CLI Release Manifest/
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `manifest.go`: validates the complete five-target archive set and writes deterministic checksums plus the immutable signed-Manifest payload for `cdn.skillsgo.ai`.
- `manifest_test.go`: specifies exact target completeness, artifact digests, URLs, and rejection of unexpected or missing release files.

## Architectural Boundary

This module assembles unsigned Manifest bytes and checksums from already-built artifacts. It does not hold signing keys, upload objects, or publish mutable channel pointers.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
