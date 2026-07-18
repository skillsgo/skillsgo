#!/usr/bin/env bash
# [INPUT]: Depends on macOS Flutter desktop support, Docker, curl, Ruby, the App workspace with its CLI bundling phase, and maintained desktop journeys.
# [OUTPUT]: Launches a clean containerized Hub and runs the App with its bundled Darwin CLI inside a fully redirected temporary macOS home.
# [POS]: Serves as the isolated lifecycle and execution adapter behind make test-e2e-app.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly workspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd "${workspace_dir}/../.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "App E2E requires macOS Flutter desktop support; skipping on $(uname -s)."
  exit 0
fi

journeys=()
while IFS= read -r journey; do
  journeys+=("${journey}")
done < <(find "${repository_root}/app/integration_test" -maxdepth 1 -name '*_test.dart' -type f | sort)
if (( ${#journeys[@]} == 0 )); then
  echo "No App E2E journeys are defined under app/integration_test." >&2
  exit 1
fi

readonly sandbox_dir="$(mktemp -d "${TMPDIR:-/tmp}/skillsgo-app-e2e.XXXXXX")"
readonly developer_home="${HOME}"
readonly developer_pub_cache="${PUB_CACHE:-${developer_home}/.pub-cache}"
readonly developer_go_path="$(go env GOPATH)"
readonly developer_go_mod_cache="$(go env GOMODCACHE)"
cleanup() {
  if [[ -n "${hub_container:-}" ]]; then
    docker rm --force "${hub_container}" >/dev/null 2>&1 || true
  fi
  chmod -R u+w "${sandbox_dir}" 2>/dev/null || true
  rm -rf "${sandbox_dir}"
}
trap cleanup EXIT INT TERM

mkdir -p \
  "${sandbox_dir}/home" \
  "${sandbox_dir}/tmp" \
  "${sandbox_dir}/hub/cache" \
  "${sandbox_dir}/hub/storage" \
  "${sandbox_dir}/test-agent/skills"

readonly hub_port="$(ruby -rsocket -e 'server = TCPServer.new("127.0.0.1", 0); puts server.addr[1]; server.close')"
readonly hub_origin="http://127.0.0.1:${hub_port}"
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
  --mount "type=bind,source=${sandbox_dir}/hub,target=/e2e/hub" \
  --env SKILLSGO_HUB_PORT=:3000 \
  --env SKILLSGO_HUB_CACHE_DIR=/e2e/hub/cache \
  --env SKILLSGO_HUB_STORAGE_TYPE=disk \
  --env SKILLSGO_HUB_DISK_STORAGE_ROOT=/e2e/hub/storage \
  --env SKILLSGO_HUB_LOG_LEVEL=info \
  "${hub_image}" >/dev/null

for _ in {1..120}; do
  if curl --fail --silent "${hub_origin}/readyz" >/dev/null; then
    break
  fi
  if [[ "$(docker inspect --format '{{.State.Running}}' "${hub_container}" 2>/dev/null || true)" != "true" ]]; then
    docker logs "${hub_container}" >&2 || true
    exit 1
  fi
  sleep 0.25
done
if ! curl --fail --silent "${hub_origin}/readyz" >/dev/null; then
  docker logs "${hub_container}" >&2 || true
  echo "Disposable App E2E Hub did not become ready." >&2
  exit 1
fi

cd "${repository_root}/app"
HOME="${sandbox_dir}/home" \
CFFIXED_USER_HOME="${sandbox_dir}/home" \
XDG_CONFIG_HOME="${sandbox_dir}/home/.config" \
XDG_CACHE_HOME="${sandbox_dir}/home/.cache" \
XDG_DATA_HOME="${sandbox_dir}/home/.local/share" \
PUB_CACHE="${developer_pub_cache}" \
GOPATH="${developer_go_path}" \
GOMODCACHE="${developer_go_mod_cache}" \
SKILLSGO_HOME="${sandbox_dir}/home/.skillsgo" \
SKILLSGO_TEST_AGENT_HOME="${sandbox_dir}/test-agent" \
SKILLSGO_HUB_URL="${hub_origin}" \
SKILLSGO_E2E_SANDBOX="${sandbox_dir}" \
flutter test \
  -d macos \
  --dart-define="SKILLSGO_HUB_URL=${hub_origin}" \
  "${journeys[@]}"
