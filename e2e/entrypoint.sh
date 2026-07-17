#!/bin/sh
# [INPUT]: Depends on a writable /e2e mount and the packaged skillsgo-hub binary.
# [OUTPUT]: Initializes isolated user, project, temporary, Hub cache, and Hub storage directories, then serves Hub in the foreground.
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

exec /sbin/tini -- /usr/local/bin/skillsgo-hub
