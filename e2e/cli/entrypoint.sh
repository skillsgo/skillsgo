#!/bin/sh
# [INPUT]: Depends on a writable /e2e mount, the packaged Hub binary, and optional Cloud-mode environment plus Mock binary.
# [OUTPUT]: Initializes isolated directories, optionally starts Cloud Mock, then serves Hub in the foreground.
# [POS]: Serves as the PID-1-safe lifecycle boundary for one disposable e2e scenario container.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
set -eu

mkdir -p \
  /e2e/home \
  /e2e/project \
  /e2e/tmp \
  /e2e/hub/cache \
  /e2e/hub/storage \
  /e2e/artifacts

/usr/local/bin/e2e-git-fixtures

if [ "${SKILLSGO_E2E_CLOUD:-}" = "1" ]; then
  /usr/local/bin/skillsgo-cloud-mock &
  cloud_pid=$!
  trap 'kill "$cloud_pid" 2>/dev/null || true' EXIT INT TERM
  attempts=0
  until wget -q -O /dev/null http://127.0.0.1:3100/__e2e/events; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 50 ]; then
      echo "Cloud mock did not become ready" >&2
      exit 1
    fi
    sleep 0.1
  done
fi

exec /sbin/tini -- /usr/local/bin/skillsgo-hub
