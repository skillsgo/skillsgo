#!/bin/sh
# [INPUT]: Depends on the system git binary and canonical fixture Repository clone arguments.
# [OUTPUT]: Adds deterministic latency only to capacity-fixture clones, then delegates every operation unchanged.
# [POS]: Serves as the controllable upstream-latency seam for anonymous Hub concurrency E2E coverage.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
set -eu

case " $* " in
  *" clone "*"https://fixtures.test/group/subgroup/capacity-"*) sleep 2 ;;
esac
exec /usr/bin/git "$@"
