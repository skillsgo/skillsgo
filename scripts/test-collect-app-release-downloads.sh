#!/usr/bin/env bash
# [INPUT]: Depends on collect-app-release-downloads.sh and standard Linux filesystem, checksum, and archive fixture utilities.
# [OUTPUT]: Verifies unsigned naming, signed artifact preference, four-download completeness, checksums, missing-artifact failure, and rejection of mixed macOS signing modes.
# [POS]: Serves as the fast release-download collection contract test executed by Linux desktop CI.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly collector="${repository_root}/scripts/collect-app-release-downloads.sh"
readonly fixture_root="$(mktemp -d)"
trap 'rm -rf "${fixture_root}"' EXIT

create_channels() {
  local assets_root="$1"
  mkdir -p \
    "${assets_root}/win-x64" \
    "${assets_root}/linux-x64" \
    "${assets_root}/osx-arm64" \
    "${assets_root}/osx-x64"
  printf 'windows' >"${assets_root}/win-x64/SkillsGo-win-x64-Setup.exe"
  printf 'linux' >"${assets_root}/linux-x64/SkillsGo-linux-x64.AppImage"
  printf 'arm portable' >"${assets_root}/osx-arm64/SkillsGo-osx-arm64-Portable.zip"
  printf 'intel portable' >"${assets_root}/osx-x64/SkillsGo-osx-x64-Portable.zip"
  printf '{"signed":false}' >"${assets_root}/win-x64/release-1.0.0.json"
  printf '{"signed":false}' >"${assets_root}/linux-x64/release-1.0.0.json"
  printf '{"signed":false}' >"${assets_root}/osx-arm64/release-1.0.0.json"
  printf '{"signed":false}' >"${assets_root}/osx-x64/release-1.0.0.json"
}

readonly unsigned_assets="${fixture_root}/unsigned-assets"
readonly unsigned_downloads="${fixture_root}/unsigned-downloads"
create_channels "${unsigned_assets}"
"${collector}" "${unsigned_assets}" "${unsigned_downloads}"

for expected in \
  SkillsGo-Windows-x64-unsigned-Setup.exe \
  SkillsGo-linux-x64.AppImage \
  SkillsGo-macOS-arm64-unsigned.zip \
  SkillsGo-macOS-x64-unsigned.zip \
  checksums.txt; do
  test -s "${unsigned_downloads}/${expected}"
done
(
  cd "${unsigned_downloads}"
  sha256sum --check checksums.txt
)

readonly signed_assets="${fixture_root}/signed-assets"
readonly signed_downloads="${fixture_root}/signed-downloads"
create_channels "${signed_assets}"
printf 'arm pkg' >"${signed_assets}/osx-arm64/SkillsGo-arm64.pkg"
printf 'intel pkg' >"${signed_assets}/osx-x64/SkillsGo-x64.pkg"
printf '{"signed":true}' >"${signed_assets}/win-x64/release-1.0.0.json"
printf '{"signed":true}' >"${signed_assets}/osx-arm64/release-1.0.0.json"
printf '{"signed":true}' >"${signed_assets}/osx-x64/release-1.0.0.json"
"${collector}" "${signed_assets}" "${signed_downloads}"

test -s "${signed_downloads}/SkillsGo-win-x64-Setup.exe"
test -s "${signed_downloads}/SkillsGo-arm64.pkg"
test -s "${signed_downloads}/SkillsGo-x64.pkg"
test ! -e "${signed_downloads}/SkillsGo-macOS-arm64-unsigned.zip"
test ! -e "${signed_downloads}/SkillsGo-macOS-x64-unsigned.zip"

readonly incomplete_assets="${fixture_root}/incomplete-assets"
readonly incomplete_downloads="${fixture_root}/incomplete-downloads"
create_channels "${incomplete_assets}"
rm "${incomplete_assets}/osx-x64/SkillsGo-osx-x64-Portable.zip"
if "${collector}" "${incomplete_assets}" "${incomplete_downloads}" >/dev/null 2>&1; then
  echo "Collector accepted a release without a macOS x64 download." >&2
  exit 1
fi

readonly mixed_assets="${fixture_root}/mixed-assets"
readonly mixed_downloads="${fixture_root}/mixed-downloads"
create_channels "${mixed_assets}"
printf 'arm pkg' >"${mixed_assets}/osx-arm64/SkillsGo-arm64.pkg"
printf '{"signed":true}' >"${mixed_assets}/osx-arm64/release-1.0.0.json"
if "${collector}" "${mixed_assets}" "${mixed_downloads}" >/dev/null 2>&1; then
  echo "Collector accepted mixed signed and unsigned macOS channels." >&2
  exit 1
fi

echo "App release download collection tests passed."
