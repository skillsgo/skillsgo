#!/bin/sh
# [INPUT]: Depends on the system git binary and canonical fixture Repository clone arguments.
# [OUTPUT]: Injects the explicit fixtures.test-to-file transport rewrite, adds deterministic capacity-fixture latency, and delegates to system Git.
# [POS]: Serves as the controlled source-transport and upstream-latency seam for Hub E2E coverage without ambient Git configuration.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
set -eu

case " $* " in
  *" clone "*"https://fixtures.test/group/subgroup/capacity-"*) sleep 2 ;;
esac
exec /usr/bin/git -c 'url.file:///e2e/git/.insteadOf=https://fixtures.test/' "$@"
