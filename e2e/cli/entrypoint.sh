#!/bin/sh
# [INPUT]: Depends on a writable /e2e mount plus the packaged Hub binary.
# [OUTPUT]: Initializes suite directories and immutable Git baselines, then keeps the reusable runtime ready for Journey-scoped Hub processes.
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

echo "SkillsGo E2E suite runtime ready"
exec /sbin/tini -- tail -f /dev/null
