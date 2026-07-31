#!/usr/bin/env bash
# [INPUT]: Depends on one structurally verified unsigned Velopack candidate produced by package-app-candidate.sh, native desktop process support, and persistent Xvfb on Linux.
# [OUTPUT]: Verifies the packaged bundled CLI version and proves the portable macOS or Linux candidate remains running after native launch.
# [POS]: Serves as the post-packaging execution gate for non-Windows App candidates; Windows installation smoke is owned by the workflow's native PowerShell step.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly target="${1:-}"
readonly architecture="${2:-}"
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly app_root="${repository_root}/app"
readonly version="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' "${app_root}/pubspec.yaml")"

case "${target}:${architecture}" in
  macos:arm64)
    readonly channel="osx-arm64"
    ;;
  macos:x86_64)
    readonly channel="osx-x64"
    ;;
  linux:x64)
    readonly channel="linux-x64"
    ;;
  *)
    echo "Usage: $0 <linux x64|macos arm64|macos x86_64>" >&2
    exit 64
    ;;
esac

readonly candidate_dir="${app_root}/build/velopack/${channel}"
readonly smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/skillsgo-candidate-smoke.XXXXXX")"
app_pid=""
xvfb_pid=""

cleanup() {
  if [[ -n "${app_pid}" ]]; then
    if [[ "${target}" == "linux" ]]; then
      kill -- "-${app_pid}" >/dev/null 2>&1 || true
    else
      kill "${app_pid}" >/dev/null 2>&1 || true
    fi
    wait "${app_pid}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${xvfb_pid}" ]]; then
    kill "${xvfb_pid}" >/dev/null 2>&1 || true
    wait "${xvfb_pid}" >/dev/null 2>&1 || true
  fi
  rm -rf "${smoke_root}"
}
trap cleanup EXIT INT TERM

if [[ "${target}" == "macos" ]]; then
  readonly portable="${candidate_dir}/SkillsGo-${channel}-Portable.zip"
  ditto -x -k "${portable}" "${smoke_root}"
  readonly app_bundle="${smoke_root}/SkillsGo.app"
  readonly cli="${app_bundle}/Contents/Resources/bin/skillsgo"
  readonly executable="${app_bundle}/Contents/MacOS/SkillsGo"
  readonly cli_version="$("${cli}" --version)"
  if [[ "${cli_version}" != "skillsgo version ${version}" ]]; then
    echo "Packaged CLI reported '${cli_version}', expected 'skillsgo version ${version}'." >&2
    exit 1
  fi
  "${executable}" >"${smoke_root}/app.log" 2>&1 &
  app_pid=$!
else
  readonly portable="${candidate_dir}/SkillsGo-${channel}.AppImage"
  chmod 0755 "${portable}"
  (
    cd "${smoke_root}"
    "${portable}" --appimage-extract >/dev/null
  )
  readonly cli="${smoke_root}/squashfs-root/usr/bin/data/bin/skillsgo"
  readonly cli_version="$("${cli}" --version)"
  if [[ "${cli_version}" != "skillsgo version ${version}" ]]; then
    echo "Packaged CLI reported '${cli_version}', expected 'skillsgo version ${version}'." >&2
    exit 1
  fi
  readonly display_number=99
  Xvfb ":${display_number}" -screen 0 1280x720x24 -nolisten tcp \
    >"${smoke_root}/xvfb.log" 2>&1 &
  xvfb_pid=$!
  sleep 0.5
  if ! kill -0 "${xvfb_pid}" >/dev/null 2>&1; then
    cat "${smoke_root}/xvfb.log" >&2 || true
    echo "Xvfb failed to start for the Linux candidate smoke." >&2
    exit 1
  fi
  setsid env DISPLAY=":${display_number}" APPIMAGE_EXTRACT_AND_RUN=1 \
    "${portable}" >"${smoke_root}/app.log" 2>&1 &
  app_pid=$!
fi

sleep 8
if ! kill -0 "${app_pid}" >/dev/null 2>&1; then
  cat "${smoke_root}/app.log" >&2
  echo "Packaged ${channel} candidate exited during startup smoke." >&2
  exit 1
fi

echo "Started packaged SkillsGo ${version} candidate for ${channel}."
