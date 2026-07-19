#!/usr/bin/env bash
# [INPUT]: Depends on process-compose, Air, process-compose.yaml, and the App, CLI, and Hub workspace development commands.
# [OUTPUT]: Validates the local development toolchain and delegates the complete development session to Process Compose.
# [POS]: Serves as the thin, stable adapter behind the repository-level make dev command; process lifecycle belongs to Process Compose.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly go_bin_dir="$(go env GOPATH)/bin"

if ! command -v process-compose >/dev/null 2>&1; then
  echo "process-compose is required. Install it with: brew install F1bonacc1/tap/process-compose" >&2
  exit 1
fi

if command -v air >/dev/null 2>&1; then
  air_bin="$(command -v air)"
elif [[ -x "${go_bin_dir}/air" ]]; then
  air_bin="${go_bin_dir}/air"
else
  echo "Air is required. Install it with: go install github.com/air-verse/air@v1.66.0" >&2
  exit 1
fi

if lsof -nP -iTCP:3000 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port 3000 is already in use. Stop the existing Hub or make dev session first." >&2
  exit 1
fi

export SKILLSGO_AIR_BIN="${air_bin}"

compose_args=(-f "${root_dir}/process-compose.yaml")
if [[ ! -t 1 || "${TERM:-dumb}" == "dumb" ]]; then
  compose_args+=(--tui=false --no-server)
fi

exec process-compose "${compose_args[@]}"
