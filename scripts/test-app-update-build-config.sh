#!/usr/bin/env bash
# [INPUT]: Depends on the macOS architecture builder and App release workflow as the production update-source/channel composition points.
# [OUTPUT]: Verifies every released desktop architecture embeds the same explicit Velopack channel used by its published feed directory.
# [POS]: Serves as a fast, network-free release configuration contract test executed by repository App checks.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly macos_builder="${repository_root}/app/macos/scripts/build_arch.sh"
readonly release_workflow="${repository_root}/.github/workflows/app-release.yml"

grep -Fq 'arm64) readonly app_update_channel="osx-arm64"' "${macos_builder}"
grep -Fq 'x86_64) readonly app_update_channel="osx-x64"' "${macos_builder}"
grep -Fq -- '--dart-define "SKILLSGO_APP_UPDATE_CHANNEL=${app_update_channel}"' "${macos_builder}"

grep -Fq 'channel: osx-arm64' "${release_workflow}"
grep -Fq 'channel: osx-x64' "${release_workflow}"
grep -Fq 'channel: linux-x64' "${release_workflow}"
grep -Fq -- '--dart-define "SKILLSGO_APP_UPDATE_CHANNEL=${RELEASE_CHANNEL}"' "${release_workflow}"

echo "App update build configuration tests passed."
