#!/bin/sh
# [INPUT]: Depends on a writable /e2e mount plus the packaged Hub and Cloud Mock binaries.
# [OUTPUT]: Initializes suite directories and immutable Git baselines, starts Cloud Mock, then keeps the reusable runtime ready for Journey-scoped Hub processes.
# [POS]: Serves as the PID-1-safe lifecycle boundary for the shared CLI e2e runtime container.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
set -eu

mkdir -p \
  /e2e/home \
  /e2e/project \
  /e2e/tmp \
  /e2e/hub/cache \
  /e2e/hub/home \
  /e2e/hub/tmp \
  /e2e/hub/storage \
  /e2e/artifacts

/usr/local/bin/e2e-git-fixtures
cp -a /e2e/git /e2e/git-baseline
cp -a /e2e/git-work /e2e/git-work-baseline

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

echo "SkillsGo E2E suite runtime ready"
exec /sbin/tini -- tail -f /dev/null
