#!/usr/bin/env bash
# [INPUT]: Depends on Flutter's PID file and SIGUSR1 Hot Reload contract plus App lib and asset source timestamps.
# [OUTPUT]: Requests Flutter Hot Reload whenever maintained App source or assets change during a development session.
# [POS]: Serves as a single-purpose watcher process supervised by Process Compose; it does not own App lifecycle.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly flutter_pid_file="/tmp/skillsgo-flutter.pid"
readonly reload_stamp="$(mktemp "${TMPDIR:-/tmp}/skillsgo-flutter-reload.XXXXXX")"

cleanup() {
  rm -f "${reload_stamp}" "${flutter_pid_file}"
}
trap cleanup EXIT
trap 'exit 0' INT TERM

while true; do
  if find "${root_dir}/app/lib" "${root_dir}/app/assets" \
    -type f -newer "${reload_stamp}" -print -quit | grep -q .; then
    touch "${reload_stamp}"
    if [[ -s "${flutter_pid_file}" ]]; then
      flutter_pid="$(<"${flutter_pid_file}")"
      if kill -0 "${flutter_pid}" 2>/dev/null; then
        echo "App source changed; requesting Flutter Hot Reload."
        kill -USR1 "${flutter_pid}"
      fi
    fi
  fi
  sleep 0.35
done
