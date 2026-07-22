#!/usr/bin/env bash
# [INPUT]: Depends on macOS Flutter desktop support, Go, curl, Ruby, the App workspace with its CLI bundling phase, isolated Hub database/cache/storage paths, and optionally Docker for the alternate Hub runtime.
# [OUTPUT]: Launches a fully disposable real Hub process and runs each selected App journey with its bundled Darwin CLI inside an independent redirected temporary macOS home.
# [POS]: Serves as the isolated lifecycle and execution adapter behind make test-e2e-app.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly workspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd "${workspace_dir}/../.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "App E2E requires macOS Flutter desktop support; skipping on $(uname -s)."
  exit 0
fi

journeys=("$@")
if (( ${#journeys[@]} == 0 )); then
  while IFS= read -r journey; do
    journeys+=("${journey}")
  done < <(find "${repository_root}/app/integration_test" -maxdepth 1 -name '*_test.dart' -type f | sort)
fi
if (( ${#journeys[@]} == 0 )); then
  echo "No App E2E journeys are defined under app/integration_test." >&2
  exit 1
fi

temp_root="${TMPDIR:-/tmp}"
readonly run_dir="$(mktemp -d "${temp_root%/}/skillsgo-app-e2e.XXXXXX")"
readonly developer_home="${HOME}"
readonly developer_pub_cache="${PUB_CACHE:-${developer_home}/.pub-cache}"
readonly developer_go_path="$(go env GOPATH)"
readonly developer_go_mod_cache="$(go env GOMODCACHE)"
cleanup() {
  if [[ -n "${hub_pid:-}" ]]; then
    kill "${hub_pid}" >/dev/null 2>&1 || true
    wait "${hub_pid}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${hub_container:-}" ]]; then
    docker rm --force "${hub_container}" >/dev/null 2>&1 || true
  fi
  chmod -R u+w "${run_dir}" 2>/dev/null || true
  rm -rf "${run_dir}"
}
trap cleanup EXIT INT TERM

mkdir -p \
  "${run_dir}/hub/cache" \
  "${run_dir}/hub/storage"

readonly hub_port="$(ruby -rsocket -e 'server = TCPServer.new("127.0.0.1", 0); puts server.addr[1]; server.close')"
readonly hub_origin="http://127.0.0.1:${hub_port}"
readonly hub_log="${run_dir}/hub.log"
readonly hub_runtime="${SKILLSGO_E2E_HUB_RUNTIME:-native}"

case "${hub_runtime}" in
  native)
    readonly hub_binary="${run_dir}/skillsgo-hub"
    (
      cd "${repository_root}/hub"
      CGO_ENABLED=0 go build -trimpath -o "${hub_binary}" ./cmd/skillsgo-hub
    )
    SKILLSGO_HUB_PORT="127.0.0.1:${hub_port}" \
    SKILLSGO_HUB_CACHE_DIR="${run_dir}/hub/cache" \
    SKILLSGO_HUB_DATABASE_DSN="${run_dir}/hub/catalog.db" \
    SKILLSGO_HUB_STORAGE_TYPE=disk \
    SKILLSGO_HUB_DISK_STORAGE_ROOT="${run_dir}/hub/storage" \
    SKILLSGO_HUB_LOG_LEVEL=info \
    "${hub_binary}" >"${hub_log}" 2>&1 &
    readonly hub_pid=$!
    ;;
  docker)
    readonly hub_image="skillsgo-app-e2e-hub:local"
    readonly hub_container="skillsgo-app-e2e-${hub_port}"
    docker build \
      --file "${workspace_dir}/Dockerfile" \
      --tag "${hub_image}" \
      "${repository_root}" >/dev/null
    docker run \
      --detach \
      --name "${hub_container}" \
      --publish "127.0.0.1:${hub_port}:3000" \
      --mount "type=bind,source=${run_dir}/hub,target=/e2e/hub" \
      --env SKILLSGO_HUB_PORT=:3000 \
      --env SKILLSGO_HUB_CACHE_DIR=/e2e/hub/cache \
      --env SKILLSGO_HUB_DATABASE_DSN=/e2e/hub/catalog.db \
      --env SKILLSGO_HUB_STORAGE_TYPE=disk \
      --env SKILLSGO_HUB_DISK_STORAGE_ROOT=/e2e/hub/storage \
      --env SKILLSGO_HUB_LOG_LEVEL=info \
      "${hub_image}" >/dev/null
    ;;
  *)
    echo "Unsupported App E2E Hub runtime: ${hub_runtime}" >&2
    exit 1
    ;;
esac

for _ in {1..120}; do
  if curl --fail --silent "${hub_origin}/readyz" >/dev/null; then
    break
  fi
  if [[ "${hub_runtime}" == "native" ]] && ! kill -0 "${hub_pid}" 2>/dev/null; then
    cat "${hub_log}" >&2 || true
    exit 1
  fi
  if [[ "${hub_runtime}" == "docker" ]] && [[ "$(docker inspect --format '{{.State.Running}}' "${hub_container}" 2>/dev/null || true)" != "true" ]]; then
    docker logs "${hub_container}" >&2 || true
    exit 1
  fi
  sleep 0.25
done
if ! curl --fail --silent "${hub_origin}/readyz" >/dev/null; then
  if [[ "${hub_runtime}" == "native" ]]; then
    cat "${hub_log}" >&2 || true
  else
    docker logs "${hub_container}" >&2 || true
  fi
  echo "Disposable App E2E Hub did not become ready." >&2
  exit 1
fi

cd "${repository_root}/app"
for journey in "${journeys[@]}"; do
  journey_name="$(basename "${journey}" .dart)"
  journey_sandbox="${run_dir}/journeys/${journey_name}"
  mkdir -p \
    "${journey_sandbox}/home" \
    "${journey_sandbox}/tmp" \
    "${journey_sandbox}/test-agent/skills"
  HOME="${journey_sandbox}/home" \
  CFFIXED_USER_HOME="${journey_sandbox}/home" \
  XDG_CONFIG_HOME="${journey_sandbox}/home/.config" \
  XDG_CACHE_HOME="${journey_sandbox}/home/.cache" \
  XDG_DATA_HOME="${journey_sandbox}/home/.local/share" \
  PUB_CACHE="${developer_pub_cache}" \
  GOPATH="${developer_go_path}" \
  GOMODCACHE="${developer_go_mod_cache}" \
  SKILLSGO_HOME="${journey_sandbox}/home/.skillsgo" \
  SKILLSGO_TEST_AGENT_HOME="${journey_sandbox}/test-agent" \
  SKILLSGO_HUB_URL="${hub_origin}" \
  SKILLSGO_E2E_SANDBOX="${journey_sandbox}" \
  flutter test \
    -d macos \
    --dart-define="SKILLSGO_HUB_URL=${hub_origin}" \
    "${journey}"
done
