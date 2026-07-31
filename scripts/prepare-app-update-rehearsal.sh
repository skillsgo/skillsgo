#!/usr/bin/env bash
# [INPUT]: Depends on a verified 0.0.1 Velopack candidate, Flutter/Go native build tools, Velopack CLI 1.2.0, and one supported target architecture.
# [OUTPUT]: Preserves the 0.0.1 launcher, builds 0.0.2 from the same source, and appends its full package to the target's local Velopack feed.
# [POS]: Serves as the deterministic two-version preparation half of the zero-cost App update E2E.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly target="${1:-}"
readonly architecture="${2:-}"
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly app_root="${repository_root}/app"
readonly baseline_version="0.0.1"
readonly update_version="0.0.2"

case "${target}:${architecture}" in
  windows:x64)
    readonly channel="win-x64"
    readonly baseline_name="SkillsGo-${channel}-Setup.exe"
    ;;
  linux:x64)
    readonly channel="linux-x64"
    readonly baseline_name="SkillsGo-${channel}.AppImage"
    ;;
  macos:arm64)
    readonly channel="osx-arm64"
    readonly baseline_name="SkillsGo-${channel}-Portable.zip"
    ;;
  macos:x86_64)
    readonly channel="osx-x64"
    readonly baseline_name="SkillsGo-${channel}-Portable.zip"
    ;;
  *)
    echo "Usage: $0 <windows x64|linux x64|macos arm64|macos x86_64>" >&2
    exit 64
    ;;
esac

readonly feed_dir="${app_root}/build/velopack/${channel}"
readonly rehearsal_dir="${app_root}/build/update-rehearsal/${channel}"
readonly baseline_dir="${rehearsal_dir}/baseline"
readonly baseline_source="${feed_dir}/${baseline_name}"

if [[ ! -s "${baseline_source}" ]]; then
  echo "Baseline Velopack launcher is missing: ${baseline_source}" >&2
  exit 1
fi
rm -rf "${rehearsal_dir}"
mkdir -p "${baseline_dir}"
cp "${baseline_source}" "${baseline_dir}/${baseline_name}"

case "${target}" in
  macos)
    SKILLSGO_APP_BUILD_NAME="${update_version}" \
      SKILLSGO_APP_BUILD_NUMBER=2 \
      "${app_root}/macos/scripts/build_arch.sh" "${architecture}"
    ;;
  windows|linux)
    (
      cd "${app_root}"
      flutter build "${target}" --release \
        --build-name "${update_version}" \
        --build-number 2
    )
    ;;
esac

SKILLSGO_APP_PACKAGE_VERSION="${update_version}" \
  SKILLSGO_APP_PACKAGE_APPEND=1 \
  "${repository_root}/scripts/package-app-candidate.sh" \
  "${target}" "${architecture}"

readonly release_manifest="${feed_dir}/releases.${channel}.json"
for expected_version in "${baseline_version}" "${update_version}"; do
  if ! grep -Fq "\"Version\":\"${expected_version}\"" "${release_manifest}"; then
    echo "Velopack feed does not retain version ${expected_version}: ${release_manifest}" >&2
    exit 1
  fi
done

echo "Prepared SkillsGo ${baseline_version} -> ${update_version} rehearsal for ${channel}."
