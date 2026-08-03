# Homebrew Distribution Metadata

This directory documents the Homebrew distribution seam. The release workflow
generates a versioned Formula from the immutable CLI archives; the generated
Formula is published to the `skillsgo/homebrew-skillsgo` tap when the repository
publisher enables that job.

The Formula is deliberately generated rather than committed with a stale
version and digest. The source generator lives at
`scripts/generate-homebrew-formula.mjs`.

Supported Homebrew targets are macOS arm64/x86_64 and Linux arm64/x86_64.
Windows remains available through the standalone archive, npm, or WinGet
distribution.
