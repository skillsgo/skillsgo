#!/usr/bin/env bash
# [INPUT]: Depends on a two-version local Velopack feed from prepare-app-update-rehearsal.sh, its preserved macOS/Linux 0.0.1 launcher, an explicit portable-App channel, Dart, and native process support.
# [OUTPUT]: Serves the feed locally, launches packaged 0.0.1 with the guarded update source, and proves Velopack replaced it with runnable 0.0.2 content and restarted the platform launcher.
# [POS]: Serves as the real check/download/apply/restart gate for unsigned macOS and Linux App updates; Windows is verified by the workflow's native PowerShell gate.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly target="${1:-}"
readonly architecture="${2:-}"
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly app_root="${repository_root}/app"
readonly update_version="0.0.2"
readonly port="38127"
readonly update_url="http://127.0.0.1:${port}/"

case "${target}:${architecture}" in
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
    echo "Usage: $0 <linux x64|macos arm64|macos x86_64>" >&2
    exit 64
    ;;
esac

readonly feed_dir="${app_root}/build/velopack/${channel}"
readonly rehearsal_dir="${app_root}/build/update-rehearsal/${channel}"
readonly baseline="${rehearsal_dir}/baseline/${baseline_name}"
readonly runtime_dir="${rehearsal_dir}/runtime"
mkdir -p "${runtime_dir}"

server_pid=""
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
  if [[ -n "${server_pid}" ]]; then
    kill "${server_pid}" >/dev/null 2>&1 || true
    wait "${server_pid}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

dart "${repository_root}/scripts/serve-update-feed.dart" \
  "${feed_dir}" "${port}" >"${runtime_dir}/feed.log" 2>&1 &
server_pid=$!
for _ in {1..50}; do
  if curl --fail --silent "${update_url}releases.${channel}.json" >/dev/null; then
    break
  fi
  sleep 0.2
done
curl --fail --silent "${update_url}releases.${channel}.json" >/dev/null

if [[ "${target}" == "macos" ]]; then
  ditto -x -k "${baseline}" "${runtime_dir}"
  readonly app_bundle="${runtime_dir}/SkillsGo.app"
  readonly executable="${app_bundle}/Contents/MacOS/SkillsGo"
  readonly cli="${app_bundle}/Contents/Resources/bin/skillsgo"
  SKILLSGO_APP_UPDATE_REHEARSAL_URL="${update_url}" \
    SKILLSGO_APP_UPDATE_REHEARSAL_CHANNEL="${channel}" \
    "${executable}" >"${runtime_dir}/app.log" 2>&1 &
  app_pid=$!
  for _ in {1..180}; do
    if [[ -x "${cli}" ]] && \
      [[ "$("${cli}" --version 2>/dev/null || true)" == "skillsgo version ${update_version}" ]]; then
      restarted_pid=""
      for _ in {1..20}; do
        restarted_pid="$(pgrep -f -x "${executable}" | head -1 || true)"
        if [[ -n "${restarted_pid}" && "${restarted_pid}" != "${app_pid}" ]]; then
          break
        fi
        sleep 0.25
      done
      if [[ -z "${restarted_pid}" || "${restarted_pid}" == "${app_pid}" ]]; then
        cat "${runtime_dir}/app.log" >&2 || true
        echo "Velopack replaced ${channel} but did not restart the updated App." >&2
        exit 1
      fi
      app_pid="${restarted_pid}"
      echo "Updated and restarted SkillsGo 0.0.1 -> ${update_version} for ${channel}."
      exit 0
    fi
    sleep 1
  done
else
  readonly appimage="${runtime_dir}/SkillsGo.AppImage"
  cp "${baseline}" "${appimage}"
  chmod 0755 "${appimage}"
  readonly baseline_sha="$(sha256sum "${appimage}" | awk '{print $1}')"
  readonly display_number=99
  Xvfb ":${display_number}" -screen 0 1280x720x24 -nolisten tcp \
    >"${runtime_dir}/xvfb.log" 2>&1 &
  xvfb_pid=$!
  sleep 0.5
  if ! kill -0 "${xvfb_pid}" >/dev/null 2>&1; then
    cat "${runtime_dir}/xvfb.log" >&2 || true
    echo "Xvfb failed to start for the Linux update rehearsal." >&2
    exit 1
  fi
  setsid env \
    DISPLAY=":${display_number}" \
    SKILLSGO_APP_UPDATE_REHEARSAL_URL="${update_url}" \
    SKILLSGO_APP_UPDATE_REHEARSAL_CHANNEL="${channel}" \
    APPIMAGE_EXTRACT_AND_RUN=1 \
    "${appimage}" >"${runtime_dir}/app.log" 2>&1 &
  app_pid=$!
  for _ in {1..180}; do
    current_sha="$(sha256sum "${appimage}" 2>/dev/null | awk '{print $1}' || true)"
    if [[ -n "${current_sha}" && "${current_sha}" != "${baseline_sha}" ]]; then
      rm -rf "${runtime_dir}/squashfs-root"
      (cd "${runtime_dir}" && "${appimage}" --appimage-extract >/dev/null)
      readonly cli="${runtime_dir}/squashfs-root/usr/bin/data/bin/skillsgo"
      if [[ "$("${cli}" --version)" == "skillsgo version ${update_version}" ]]; then
        restarted_pid=""
        for _ in {1..20}; do
          restarted_pid="$(pgrep -f -x -- "${appimage}" | head -1 || true)"
          if [[ -n "${restarted_pid}" ]]; then
            break
          fi
          sleep 0.25
        done
        if [[ -z "${restarted_pid}" ]]; then
          cat "${runtime_dir}/app.log" >&2 || true
          echo "Velopack replaced ${channel} but did not restart the updated AppImage." >&2
          exit 1
        fi
        echo "Updated and restarted SkillsGo 0.0.1 -> ${update_version} for ${channel}."
        exit 0
      fi
    fi
    sleep 1
  done
fi

cat "${runtime_dir}/feed.log" >&2 || true
cat "${runtime_dir}/app.log" >&2 || true
echo "Timed out waiting for SkillsGo ${channel} to update to ${update_version}." >&2
exit 1
