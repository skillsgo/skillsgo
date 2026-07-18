#!/usr/bin/env bash
# [INPUT]: Depends on the Hub and CLI Makefiles, curl, lsof, Flutter signal-based reload control, and the macOS desktop target.
# [OUTPUT]: Runs one local development session containing a debug-logging Hub, the freshly built CLI, and the macOS App with save-triggered Hot Reload plus manual Flutter controls.
# [POS]: Serves as the process supervisor behind the repository-level make dev command.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly hub_url="http://127.0.0.1:3000"
readonly dev_runtime_dir="$(mktemp -d "${TMPDIR:-/tmp}/skillsgo-dev.XXXXXX")"
readonly flutter_pid_file="${dev_runtime_dir}/flutter.pid"
readonly reload_stamp="${dev_runtime_dir}/reload.stamp"

hub_pid=""
app_pid=""
watcher_pid=""

cleanup() {
  local exit_code=$?
  trap - EXIT INT TERM

  if [[ -n "${watcher_pid}" ]] && kill -0 "${watcher_pid}" 2>/dev/null; then
    kill -TERM "${watcher_pid}" 2>/dev/null || true
  fi
  if [[ -n "${app_pid}" ]] && kill -0 "${app_pid}" 2>/dev/null; then
    kill -TERM "${app_pid}" 2>/dev/null || true
  fi
  if [[ -n "${hub_pid}" ]] && kill -0 "${hub_pid}" 2>/dev/null; then
    kill -TERM "${hub_pid}" 2>/dev/null || true
  fi

  [[ -z "${watcher_pid}" ]] || wait "${watcher_pid}" 2>/dev/null || true
  [[ -z "${app_pid}" ]] || wait "${app_pid}" 2>/dev/null || true
  [[ -z "${hub_pid}" ]] || wait "${hub_pid}" 2>/dev/null || true
  rm -rf "${dev_runtime_dir}"
  exit "${exit_code}"
}
trap cleanup EXIT INT TERM

if lsof -nP -iTCP:3000 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port 3000 is already in use. Stop the existing Hub or make dev session first." >&2
  exit 1
fi

make -C "${root_dir}/hub" build
SKILLSGO_HUB_LOG_LEVEL=debug "${root_dir}/hub/bin/skillsgo-hub" \
  -config_file="${root_dir}/hub/config.dev.toml" &
hub_pid=$!

ready=false
for _ in {1..100}; do
  if ! kill -0 "${hub_pid}" 2>/dev/null; then
    echo "Hub exited before becoming ready." >&2
    wait "${hub_pid}"
    exit 1
  fi
  if curl --fail --silent --output /dev/null "${hub_url}/readyz"; then
    ready=true
    break
  fi
  sleep 0.2
done

if [[ "${ready}" != true ]]; then
  echo "Hub did not become ready at ${hub_url}/readyz." >&2
  exit 1
fi

make -C "${root_dir}/cli" build

touch "${reload_stamp}"
(
  cd "${root_dir}/app"
  SKILLSGO_CLI_PATH="${root_dir}/cli/bin/skillsgo" \
    flutter run -d macos --pid-file="${flutter_pid_file}"
) &
app_pid=$!

(
  while kill -0 "${app_pid}" 2>/dev/null; do
    if find \
      "${root_dir}/app/lib" \
      "${root_dir}/app/assets" \
      -type f -newer "${reload_stamp}" -print -quit | grep -q .; then
      touch "${reload_stamp}"
      if [[ -s "${flutter_pid_file}" ]]; then
        flutter_pid="$(<"${flutter_pid_file}")"
        if kill -0 "${flutter_pid}" 2>/dev/null; then
          echo "App source changed; running Hot Reload."
          kill -USR1 "${flutter_pid}"
        fi
      fi
    fi
    sleep 0.35
  done
) &
watcher_pid=$!

wait "${app_pid}"
