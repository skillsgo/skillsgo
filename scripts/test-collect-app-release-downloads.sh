#!/usr/bin/env bash
# [INPUT]: Depends on collect-app-release-downloads.sh and standard Linux filesystem and checksum utilities over synthetic installer fixtures.
# [OUTPUT]: Verifies unsigned and signed macOS naming, four-download completeness, Windows installer collection, checksums, missing-installer failure, and rejection of mixed macOS signing modes.
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
    "${assets_root}/linux-x64" \
    "${assets_root}/osx-arm64" \
    "${assets_root}/osx-x64" \
    "${assets_root}/win-x64"
  printf 'linux' >"${assets_root}/linux-x64/SkillsGo-linux-x64.AppImage"
  printf 'arm portable' >"${assets_root}/osx-arm64/SkillsGo-osx-arm64-Portable.zip"
  printf 'intel portable' >"${assets_root}/osx-x64/SkillsGo-osx-x64-Portable.zip"
  printf 'arm dmg' >"${assets_root}/osx-arm64/SkillsGo-macOS-arm64.dmg"
  printf 'intel dmg' >"${assets_root}/osx-x64/SkillsGo-macOS-x64.dmg"
  printf 'windows setup' >"${assets_root}/win-x64/SkillsGo-win-x64-Setup.exe"
  printf 'arm update pkg' >"${assets_root}/osx-arm64/SkillsGo-arm64.pkg"
  printf 'intel update pkg' >"${assets_root}/osx-x64/SkillsGo-x64.pkg"
  printf '{"signed":false}' >"${assets_root}/linux-x64/release-1.0.0.json"
  printf '{"signed":false}' >"${assets_root}/osx-arm64/release-1.0.0.json"
  printf '{"signed":false}' >"${assets_root}/osx-x64/release-1.0.0.json"
}

readonly unsigned_assets="${fixture_root}/unsigned-assets"
readonly unsigned_downloads="${fixture_root}/unsigned-downloads"
create_channels "${unsigned_assets}"
"${collector}" "${unsigned_assets}" "${unsigned_downloads}"

for expected in \
  SkillsGo-linux-x64.AppImage \
  SkillsGo-macOS-arm64-unsigned.dmg \
  SkillsGo-macOS-x64-unsigned.dmg \
  SkillsGo-win-x64-Setup.exe \
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
printf '{"signed":true}' >"${signed_assets}/osx-arm64/release-1.0.0.json"
printf '{"signed":true}' >"${signed_assets}/osx-x64/release-1.0.0.json"
"${collector}" "${signed_assets}" "${signed_downloads}"

test -s "${signed_downloads}/SkillsGo-macOS-arm64.dmg"
test -s "${signed_downloads}/SkillsGo-macOS-x64.dmg"
test -s "${signed_downloads}/SkillsGo-win-x64-Setup.exe"
test ! -e "${signed_downloads}/SkillsGo-macOS-arm64-unsigned.dmg"
test ! -e "${signed_downloads}/SkillsGo-macOS-x64-unsigned.dmg"
test ! -e "${signed_downloads}/SkillsGo-arm64.pkg"
test ! -e "${signed_downloads}/SkillsGo-x64.pkg"

readonly incomplete_assets="${fixture_root}/incomplete-assets"
readonly incomplete_downloads="${fixture_root}/incomplete-downloads"
create_channels "${incomplete_assets}"
rm "${incomplete_assets}/osx-x64/SkillsGo-macOS-x64.dmg"
if "${collector}" "${incomplete_assets}" "${incomplete_downloads}" >/dev/null 2>&1; then
  echo "Collector accepted a release without a macOS x64 DMG." >&2
  exit 1
fi

readonly mixed_assets="${fixture_root}/mixed-assets"
readonly mixed_downloads="${fixture_root}/mixed-downloads"
create_channels "${mixed_assets}"
printf '{"signed":true}' >"${mixed_assets}/osx-arm64/release-1.0.0.json"
if "${collector}" "${mixed_assets}" "${mixed_downloads}" >/dev/null 2>&1; then
  echo "Collector accepted mixed signed and unsigned macOS channels." >&2
  exit 1
fi

echo "App release download collection tests passed."
