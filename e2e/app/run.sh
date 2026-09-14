#!/usr/bin/env bash
# [INPUT]: Depends on Flutter desktop support for the host platform, reusable Go/Rust/Pub caches, native or Docker PostgreSQL, Xvfb on Linux, the OSS App and same-repository CLI/Hub source, and the persistent App E2E Runner protocol.
# [OUTPUT]: Reuses one source-fingerprinted Flutter App process across invocations, executes selected Journeys with Journey-scoped data isolation, and automatically replaces stale or failed Runner processes.
# [POS]: Serves as the persistent local execution adapter behind make test-e2e-app while keeping its existing command interface.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly workspace_dir="${SKILLSGO_E2E_WORKSPACE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
readonly repository_root="${SKILLSGO_E2E_REPOSITORY_ROOT:-$(cd "${workspace_dir}/../.." && pwd)}"
readonly public_source_root="${SKILLSGO_PUBLIC_SOURCE_ROOT:-${repository_root}}"
readonly script_path="${SKILLSGO_E2E_SCRIPT_PATH:-${workspace_dir}/run.sh}"
readonly runner_state_dir="${repository_root}/app/build/e2e-runner"
readonly runner_control_file="${runner_state_dir}/control.json"
readonly runner_pid_file="${runner_state_dir}/host.pid"
readonly runner_fingerprint_file="${runner_state_dir}/source.fingerprint"
readonly runner_log_file="${runner_state_dir}/host.log"
readonly runner_client="${workspace_dir}/runner_client.dart"
readonly runner_launcher="${workspace_dir}/runner_launcher.dart"

if [[ "${SKILLSGO_E2E_RUNNER_HOST:-0}" == "1" && -n "${SKILLSGO_E2E_RUNNER_LOG:-}" ]]; then
  exec </dev/null >>"${SKILLSGO_E2E_RUNNER_LOG}" 2>&1
fi

source_fingerprint() {
  (
    cd "${repository_root}"
    git rev-parse HEAD
    git diff --binary HEAD -- app/lib app/integration_test app/pubspec.yaml app/pubspec.lock app/macos e2e/app \
      ':(exclude)app/lib/l10n/app_localizations*.dart' \
      ':(exclude)app/macos/Flutter/GeneratedPluginRegistrant.swift' \
      ':(exclude)app/macos/Podfile.lock'
    while IFS= read -r source_file; do
      git hash-object "${source_file}"
    done < <(git ls-files --others --exclude-standard -- app/lib app/integration_test app/pubspec.yaml app/pubspec.lock app/macos e2e/app \
      ':(exclude)app/lib/l10n/app_localizations*.dart' \
      ':(exclude)app/macos/Flutter/GeneratedPluginRegistrant.swift' \
      ':(exclude)app/macos/Podfile.lock')
    git -C "${public_source_root}" rev-parse HEAD
    git -C "${public_source_root}" diff --binary HEAD -- cli protocol hub
  ) | git hash-object --stdin
}

runner_request() {
  dart "${runner_client}" "${runner_control_file}" "$@"
}

runner_is_ready() {
  [[ -f "${runner_control_file}" ]] && runner_request --ping >/dev/null 2>&1
}

runner_pid_is_host() {
  [[ "$1" =~ ^[0-9]+$ ]] || return 1
  if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
    powershell.exe -NoProfile -NonInteractive -Command \
      "\$process = Get-CimInstance Win32_Process -Filter 'ProcessId = $1'; if (\$process.CommandLine -like '*e2e-runner*host.sh*') { exit 0 } else { exit 1 }" \
      >/dev/null 2>&1
    return
  fi
  runner_command="$(ps -p "$1" -o command= 2>/dev/null || true)"
  [[ "${runner_command}" == *"${runner_state_dir}/host.sh"* ]]
}

runner_process_is_alive() {
  if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
    powershell.exe -NoProfile -NonInteractive -Command \
      "if (Get-Process -Id $1 -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" \
      >/dev/null 2>&1
    return
  fi
  kill -0 "$1" 2>/dev/null
}

terminate_runner_process() {
  if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
    powershell.exe -NoProfile -NonInteractive -Command \
      "Stop-Process -Id $1 -Force -ErrorAction SilentlyContinue" >/dev/null 2>&1 || true
    return
  fi
  kill "$1" 2>/dev/null || true
}

stop_runner() {
  runner_request --shutdown >/dev/null 2>&1 || true
  if [[ -f "${runner_pid_file}" ]]; then
    runner_pid="$(<"${runner_pid_file}")"
    if runner_pid_is_host "${runner_pid}" && runner_process_is_alive "${runner_pid}"; then
      for _ in {1..40}; do
        runner_process_is_alive "${runner_pid}" || break
        sleep 0.25
      done
      if runner_process_is_alive "${runner_pid}"; then
        terminate_runner_process "${runner_pid}"
        for _ in {1..40}; do
          runner_process_is_alive "${runner_pid}" || break
          sleep 0.25
        done
      fi
    fi
  fi
  rm -f "${runner_control_file}" "${runner_pid_file}"
}

journey_name() {
  case "$(basename "$1")" in
    repository_install_all_test.dart|repository_install_all) echo repository_install_all ;;
    package_update_check_test.dart|package_update_preview) echo package_update_preview ;;
    adoption_management_test.dart|adoption_management) echo adoption_management ;;
    machine_failure_recovery_test.dart|machine_failure_recovery) echo machine_failure_recovery ;;
    *) echo "Unsupported App E2E Journey: $1" >&2; return 64 ;;
  esac
}

if [[ "${SKILLSGO_E2E_RUNNER_HOST:-0}" != "1" ]]; then
  mkdir -p "${runner_state_dir}"
  chmod 0700 "${runner_state_dir}"
  if [[ "${1:-}" == "--shutdown" ]]; then
    stop_runner
    echo "Persistent App E2E Runner stopped."
    exit 0
  fi

  requested_fingerprint="$(source_fingerprint)"
  current_fingerprint=""
  [[ -f "${runner_fingerprint_file}" ]] && current_fingerprint="$(<"${runner_fingerprint_file}")"
  if [[ "${requested_fingerprint}" != "${current_fingerprint}" ]] || ! runner_is_ready; then
    readonly start_lock="${runner_state_dir}/start.lock"
    lock_acquired=0
    for _ in {1..120}; do
      if mkdir "${start_lock}" 2>/dev/null; then
        printf '%s\n' "$$" >"${start_lock}/owner.pid"
        lock_acquired=1
        break
      fi
      if [[ -f "${start_lock}/owner.pid" ]]; then
        lock_owner="$(<"${start_lock}/owner.pid")"
        if [[ ! "${lock_owner}" =~ ^[0-9]+$ ]] || ! kill -0 "${lock_owner}" 2>/dev/null; then
          rm -f "${start_lock}/owner.pid"
          rmdir "${start_lock}" 2>/dev/null || true
          continue
        fi
      fi
      sleep 0.25
    done
    if [[ "${lock_acquired}" != "1" ]]; then
      echo "Timed out waiting for the App E2E Runner startup lock." >&2
      exit 75
    fi
    trap 'rm -f "${start_lock}/owner.pid"; rmdir "${start_lock}" 2>/dev/null || true' EXIT INT TERM
    current_fingerprint=""
    [[ -f "${runner_fingerprint_file}" ]] && current_fingerprint="$(<"${runner_fingerprint_file}")"
    if [[ "${requested_fingerprint}" != "${current_fingerprint}" ]] || ! runner_is_ready; then
      stop_runner
      runner_token="$(openssl rand -hex 32)"
      runner_host_script="${runner_state_dir}/host.sh"
      cp "${script_path}" "${runner_host_script}"
      chmod 0700 "${runner_host_script}"
      : >"${runner_log_file}"
      dart "${runner_launcher}" "${runner_host_script}" "${runner_log_file}" "${runner_pid_file}" \
        "${runner_token}" "${workspace_dir}" "${repository_root}" "${runner_host_script}"
      printf '%s\n' "${requested_fingerprint}" >"${runner_fingerprint_file}"
      # A cold native Flutter build can exceed three minutes on a contended
      # hosted runner. This is only an upper bound: readiness exits immediately.
      startup_attempts=3600
      for (( startup_attempt = 0; startup_attempt < startup_attempts; startup_attempt++ )); do
        if runner_is_ready; then break; fi
        if [[ ! -f "${runner_pid_file}" ]]; then
          sleep 0.25
          continue
        fi
        runner_pid="$(<"${runner_pid_file}")"
        if [[ "$(uname -s)" != MINGW* && "$(uname -s)" != MSYS* && "$(uname -s)" != CYGWIN* ]] && \
          ! runner_process_is_alive "${runner_pid}"; then
          echo "Persistent App E2E Runner exited during startup:" >&2
          tail -n 120 "${runner_log_file}" >&2
          exit 75
        fi
        sleep 0.25
      done
      if ! runner_is_ready; then
        echo "Timed out starting the persistent App E2E Runner." >&2
        tail -n 120 "${runner_log_file}" >&2
        exit 75
      fi
      chmod 0600 "${runner_control_file}" "${runner_pid_file}" "${runner_fingerprint_file}"
    fi
    rm -f "${start_lock}/owner.pid"
    rmdir "${start_lock}"
    trap - EXIT INT TERM
  fi

  requested_journeys=()
  if (( $# == 0 )); then
    requested_journeys=(repository_install_all package_update_preview adoption_management machine_failure_recovery)
  else
    for requested_path in "$@"; do
      requested_journeys+=("$(journey_name "${requested_path}")")
    done
  fi
  request_status=0
  runner_request "${requested_journeys[@]}" || request_status=$?
  if [[ "${request_status}" -ne 0 && "$(uname -s)" == "Linux" && \
    "${SKILLSGO_E2E_LINUX_PROTOCOL_RETRY:-0}" != "1" ]] && \
    grep -Eq 'WebSocketChannelException: HttpException: Connection closed before full header was received|No tests were found' "${runner_log_file}"; then
    echo "Flutter Linux test protocol disconnected; restarting the Runner and retrying once." >&2
    stop_runner
    pkill -f -x "${repository_root}/app/build/linux/x64/debug/bundle/skillsgo" >/dev/null 2>&1 || true
    rm -f "${runner_fingerprint_file}"
    SKILLSGO_E2E_LINUX_PROTOCOL_RETRY=1 exec "${script_path}" "$@"
  fi
  if [[ "${request_status}" -ne 0 ]]; then
    echo "App E2E Runner diagnostics:" >&2
    tail -n 240 "${runner_log_file}" >&2 || true
  fi
  exit "${request_status}"
fi

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

journeys=("${repository_root}/app/integration_test/app_e2e_runner_test.dart")

rm -rf "${runner_state_dir}/runtime"
readonly run_dir="${runner_state_dir}/runtime"
mkdir -p "${run_dir}"
mkdir -p "${run_dir}/app-home"
readonly developer_home="${HOME}"
readonly developer_pub_cache="${PUB_CACHE:-${developer_home}/.pub-cache}"
readonly developer_cargo_home="${CARGO_HOME:-${developer_home}/.cargo}"
readonly developer_rustup_home="${RUSTUP_HOME:-${developer_home}/.rustup}"
readonly developer_go_path="$(go env GOPATH)"
readonly developer_go_mod_cache="$(go env GOMODCACHE)"
readonly developer_go_build_cache="$(go env GOCACHE)"
readonly postgres_runtime="${SKILLSGO_E2E_POSTGRES_RUNTIME:-native}"

test_path="${PATH}"
if [[ "${flutter_device}" == "macos" ]]; then
  mkdir -p "${run_dir}/host-bin"
  printf '#!/usr/bin/env bash\nif /usr/bin/open "$@"; then exit 0; fi\nHOME=%q CFFIXED_USER_HOME=%q exec /usr/bin/open "$@"\n' \
    "${developer_home}" "${developer_home}" >"${run_dir}/host-bin/open"
  chmod 0755 "${run_dir}/host-bin/open"
  test_path="${run_dir}/host-bin:${test_path}"
fi
readonly test_path

cleanup() {
  if [[ -n "${postgres_bin_dir:-}" && -n "${postgres_data_dir:-}" && -d "${postgres_data_dir}" ]]; then
    "${postgres_owner_command[@]}" "${postgres_bin_dir}/pg_ctl" \
      -D "${postgres_data_dir}" stop --mode=immediate >/dev/null 2>&1 || true
    rm -rf "${postgres_data_dir}"
  fi
  if [[ -n "${postgres_container:-}" ]]; then
    docker rm --force "${postgres_container}" >/dev/null 2>&1 || true
  fi
  chmod -R u+w "${run_dir}" 2>/dev/null || true
  rm -rf "${run_dir}"
  if [[ -f "${runner_pid_file}" ]] && [[ "$(<"${runner_pid_file}")" == "$$" ]]; then
    rm -f "${runner_control_file}" "${runner_pid_file}"
  fi
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
    readonly postgres_port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
    postgres_owner_command=(env)
    if [[ "${flutter_device}" == "linux" && "$(id -u)" == "0" ]]; then
      postgres_owner_command=(runuser -u postgres --)
      postgres_data_dir="$(mktemp -d /tmp/skillsgo-e2e-postgres.XXXXXX)"
      chown postgres:postgres "${postgres_data_dir}"
    else
      postgres_data_dir="${run_dir}/postgres"
    fi
    readonly postgres_owner_command postgres_data_dir
    "${postgres_owner_command[@]}" "${postgres_bin_dir}/initdb" \
      -D "${postgres_data_dir}" -U skillsgo --auth=trust >/dev/null
    postgres_options="-h 127.0.0.1 -p ${postgres_port}"
    if [[ "${flutter_device}" == "linux" ]]; then
      postgres_options+=" -k ${postgres_data_dir}"
    fi
    readonly postgres_options
    if ! "${postgres_owner_command[@]}" "${postgres_bin_dir}/pg_ctl" \
      -D "${postgres_data_dir}" -l "${postgres_data_dir}/postgres.log" \
      -o "${postgres_options}" start >/dev/null; then
      cat "${postgres_data_dir}/postgres.log" >&2
      exit 1
    fi
    "${postgres_bin_dir}/createdb" -h 127.0.0.1 -p "${postgres_port}" -U skillsgo skillsgo
    readonly database_dsn="postgres://skillsgo@127.0.0.1:${postgres_port}/skillsgo?sslmode=disable"
    readonly psql_binary="${postgres_bin_dir}/psql"
    ;;
  docker)
    readonly postgres_port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
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
  cd "${public_source_root}/hub"
  CGO_ENABLED=0 go build -trimpath -o "${hub_binary}" ./cmd/skillsgo-hub
)

cd "${repository_root}/app"
test_environment=(env \
  PATH="${test_path}" \
  HOME="${run_dir}/app-home" \
  CFFIXED_USER_HOME="${run_dir}/app-home" \
  XDG_CONFIG_HOME="${run_dir}/app-home/.config" \
  XDG_CACHE_HOME="${run_dir}/app-home/.cache" \
  XDG_DATA_HOME="${run_dir}/app-home/.local/share" \
  PUB_CACHE="${developer_pub_cache}" \
  CARGO_HOME="${developer_cargo_home}" \
  RUSTUP_HOME="${developer_rustup_home}" \
  GOPATH="${developer_go_path}" \
  GOMODCACHE="${developer_go_mod_cache}" \
  GOCACHE="${developer_go_build_cache}" \
  SKILLSGO_E2E_ROOT="${run_dir}" \
  SKILLSGO_E2E_DATABASE_DSN="${database_dsn}" \
  SKILLSGO_E2E_PSQL="${psql_binary}" \
  SKILLSGO_E2E_HUB_BINARY="${hub_binary}")
test_environment+=(SKILLSGO_E2E_CONTROL_FILE="${runner_control_file}" SKILLSGO_E2E_CONTROL_TOKEN="${SKILLSGO_E2E_CONTROL_TOKEN}")
test_command=(flutter test -d "${flutter_device}" "${journeys[@]}")
test_status=0
if [[ "${flutter_device}" == "linux" ]]; then
  "${test_environment[@]}" xvfb-run -a "${test_command[@]}" || test_status=$?
else
  "${test_environment[@]}" "${test_command[@]}" || test_status=$?
fi

exit "${test_status}"
