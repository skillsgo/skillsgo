#!/usr/bin/env bash
# [INPUT]: Depends on Flutter desktop support for the host platform, Go, native or Docker PostgreSQL, Xvfb on Linux, the App workspace with its CLI bundling phase, and the aggregate App E2E test entry.
# [OUTPUT]: Starts one disposable PostgreSQL instance, builds one host-native Hub binary, executes all selected App Journeys through one Flutter desktop test build with Journey-scoped runtime isolation and a compact Windows sandbox root, retries one Linux Flutter protocol exit 79 in a fresh suite runtime, and retries one macOS foreground-launch failure.
# [POS]: Serves as the suite-scoped lifecycle and single-build execution adapter behind make test-e2e-app.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly workspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd "${workspace_dir}/../.." && pwd)"

case "$(uname -s)" in
  Darwin)
    readonly flutter_device="macos"
    readonly hub_binary_name="skillsgo-hub"
    ;;
  Linux)
    readonly flutter_device="linux"
    readonly hub_binary_name="skillsgo-hub"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    readonly flutter_device="windows"
    readonly hub_binary_name="skillsgo-hub.exe"
    ;;
  *)
    echo "Unsupported App E2E host: $(uname -s)" >&2
    exit 1
    ;;
esac

journeys=("$@")
if (( ${#journeys[@]} == 0 )); then
  journeys=("${repository_root}/app/integration_test/app_e2e_suite_test.dart")
fi

if [[ "${flutter_device}" == "windows" ]]; then
  temp_template="/c/sg.XXXXXX"
else
  temp_root="${TMPDIR:-/tmp}"
  temp_template="${temp_root%/}/skillsgo-app-e2e.XXXXXX"
fi
readonly run_dir="$(mktemp -d "${temp_template}")"
mkdir -p "${run_dir}/app-home"
readonly developer_home="${HOME}"
readonly developer_pub_cache="${PUB_CACHE:-${developer_home}/.pub-cache}"
readonly developer_go_path="$(go env GOPATH)"
readonly developer_go_mod_cache="$(go env GOMODCACHE)"
readonly postgres_runtime="${SKILLSGO_E2E_POSTGRES_RUNTIME:-native}"

cleanup() {
  if [[ -n "${postgres_bin_dir:-}" && -d "${run_dir}/postgres" ]]; then
    "${postgres_bin_dir}/pg_ctl" -D "${run_dir}/postgres" stop --mode=immediate >/dev/null 2>&1 || true
  fi
  if [[ -n "${postgres_container:-}" ]]; then
    docker rm --force "${postgres_container}" >/dev/null 2>&1 || true
  fi
  chmod -R u+w "${run_dir}" 2>/dev/null || true
  rm -rf "${run_dir}"
}
trap cleanup EXIT INT TERM

case "${postgres_runtime}" in
  native)
    if [[ -n "${SKILLSGO_E2E_POSTGRES_BIN_DIR:-}" ]]; then
      postgres_bin_dir="${SKILLSGO_E2E_POSTGRES_BIN_DIR}"
    elif command -v pg_config >/dev/null 2>&1 && [[ -x "$(pg_config --bindir)/initdb" && -x "$(pg_config --bindir)/postgres" ]]; then
      postgres_bin_dir="$(pg_config --bindir)"
    elif command -v brew >/dev/null 2>&1 && postgres_prefix="$(brew --prefix postgresql@18 2>/dev/null)" && [[ -x "${postgres_prefix}/bin/initdb" ]]; then
      postgres_bin_dir="${postgres_prefix}/bin"
    else
      echo "Native App E2E requires PostgreSQL client and server binaries." >&2
      exit 1
    fi
    readonly postgres_bin_dir
    readonly postgres_port="$(ruby -rsocket -e 'server = TCPServer.new("127.0.0.1", 0); puts server.addr[1]; server.close')"
    "${postgres_bin_dir}/initdb" -D "${run_dir}/postgres" -U skillsgo --auth=trust >/dev/null
    postgres_options="-h 127.0.0.1 -p ${postgres_port}"
    if [[ "${flutter_device}" == "linux" ]]; then
      postgres_options+=" -k ${run_dir}"
    fi
    readonly postgres_options
    if ! "${postgres_bin_dir}/pg_ctl" -D "${run_dir}/postgres" -l "${run_dir}/postgres.log" -o "${postgres_options}" start >/dev/null; then
      cat "${run_dir}/postgres.log" >&2
      exit 1
    fi
    "${postgres_bin_dir}/createdb" -h 127.0.0.1 -p "${postgres_port}" -U skillsgo skillsgo
    readonly database_dsn="postgres://skillsgo@127.0.0.1:${postgres_port}/skillsgo?sslmode=disable"
    readonly psql_binary="${postgres_bin_dir}/psql"
    ;;
  docker)
    readonly postgres_port="$(ruby -rsocket -e 'server = TCPServer.new("127.0.0.1", 0); puts server.addr[1]; server.close')"
    readonly postgres_container="skillsgo-app-e2e-postgres-${postgres_port}"
    docker run --detach --name "${postgres_container}" --publish "127.0.0.1:${postgres_port}:5432" \
      --env POSTGRES_DB=skillsgo --env POSTGRES_USER=skillsgo --env POSTGRES_PASSWORD=skillsgo \
      postgres:18-alpine >/dev/null
    for _ in {1..60}; do
      if docker exec "${postgres_container}" pg_isready -U skillsgo -d skillsgo >/dev/null 2>&1; then break; fi
      sleep 0.25
    done
    readonly database_dsn="postgres://skillsgo:skillsgo@127.0.0.1:${postgres_port}/skillsgo?sslmode=disable"
    readonly psql_binary="${run_dir}/psql"
    printf '#!/usr/bin/env bash\nexec docker exec -i %q psql "$@"\n' "${postgres_container}" >"${psql_binary}"
    chmod 0755 "${psql_binary}"
    ;;
  *)
    echo "Unsupported App E2E PostgreSQL runtime: ${postgres_runtime}" >&2
    exit 1
    ;;
esac

readonly hub_binary="${run_dir}/${hub_binary_name}"
(
  cd "${repository_root}/hub"
  CGO_ENABLED=0 go build -trimpath -o "${hub_binary}" ./cmd/skillsgo-hub
)

cd "${repository_root}/app"
test_environment=(env \
  HOME="${run_dir}/app-home" \
  CFFIXED_USER_HOME="${run_dir}/app-home" \
  XDG_CONFIG_HOME="${run_dir}/app-home/.config" \
  XDG_CACHE_HOME="${run_dir}/app-home/.cache" \
  XDG_DATA_HOME="${run_dir}/app-home/.local/share" \
  PUB_CACHE="${developer_pub_cache}" \
  GOPATH="${developer_go_path}" \
  GOMODCACHE="${developer_go_mod_cache}" \
  SKILLSGO_E2E_ROOT="${run_dir}" \
  SKILLSGO_E2E_DATABASE_DSN="${database_dsn}" \
  SKILLSGO_E2E_PSQL="${psql_binary}" \
  SKILLSGO_E2E_HUB_BINARY="${hub_binary}")
test_command=(flutter test -d "${flutter_device}" "${journeys[@]}")
test_status=0
if [[ "${flutter_device}" == "linux" ]]; then
  "${test_environment[@]}" xvfb-run -a "${test_command[@]}" || test_status=$?
elif [[ "${flutter_device}" == "macos" ]]; then
  readonly flutter_test_log="${run_dir}/flutter-test.log"
  "${test_environment[@]}" "${test_command[@]}" 2>&1 | tee "${flutter_test_log}" || test_status=$?
else
  "${test_environment[@]}" "${test_command[@]}" || test_status=$?
fi

if [[ "${flutter_device}" == "macos" && "${test_status}" -ne 0 ]] && grep -Fq "Failed to foreground app; open returned" "${flutter_test_log}"; then
  echo "Flutter macOS failed to foreground the test App; retrying once." >&2
  "${psql_binary}" "${database_dsn}" --set ON_ERROR_STOP=1 --command \
    'DO $reset$ DECLARE item record; BEGIN FOR item IN SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE '\''app_e2e_%'\'' LOOP EXECUTE format('\''DROP SCHEMA %I CASCADE'\'', item.schema_name); END LOOP; END $reset$;' >/dev/null
  test_status=0
  "${test_environment[@]}" "${test_command[@]}" || test_status=$?
fi

if [[ "${flutter_device}" == "linux" && "${test_status}" -eq 79 && "${SKILLSGO_E2E_LINUX_PROTOCOL_RETRY:-0}" != "1" ]]; then
  echo "Flutter Linux test protocol exited 79; retrying once with a fresh suite runtime." >&2
  cleanup
  trap - EXIT INT TERM
  SKILLSGO_E2E_LINUX_PROTOCOL_RETRY=1 exec "$0" "$@"
fi
exit "${test_status}"
