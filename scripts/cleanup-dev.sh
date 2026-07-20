#!/usr/bin/env bash
# [INPUT]: Depends on the macOS ps and lsof process views plus the commands declared by process-compose.yaml.
# [OUTPUT]: Stops stale development process trees owned by the current SkillsGo checkout, with optional dry-run reporting.
# [POS]: Serves as the safety boundary between make dev startup and any previously orphaned local development processes.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly grace_seconds="${SKILLSGO_DEV_CLEANUP_GRACE_SECONDS:-5}"
readonly flutter_pid_file="/tmp/skillsgo-flutter.pid"
dry_run=false

if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--dry-run]" >&2
  exit 2
fi

if ! [[ "${grace_seconds}" =~ ^[0-9]+$ ]]; then
  echo "SKILLSGO_DEV_CLEANUP_GRACE_SECONDS must be a non-negative integer." >&2
  exit 2
fi

process_snapshot="$(ps -axo pid=,ppid=,command=)"
candidate_pids=()
target_pids=()

process_cwd() {
  local pid="$1"
  local line

  while IFS= read -r line; do
    if [[ "${line}" == n* ]]; then
      printf '%s\n' "${line#n}"
      return 0
    fi
  done < <(lsof -a -p "${pid}" -d cwd -Fn 2>/dev/null || true)

  return 1
}

is_known_dev_command() {
  local command="$1"

  case "${command}" in
    process-compose\ * | */process-compose\ *)
      [[ "${command}" == *process-compose.yaml* ]]
      return
      ;;
    "bash ./scripts/watch-flutter.sh" | \
      "/bin/bash ./scripts/watch-flutter.sh" | \
      "${root_dir}/scripts/watch-flutter.sh")
      return 0
      ;;
    air\ * | */air\ *)
      [[ "${command}" == *" -c .air.toml"* ]]
      return
      ;;
    "${root_dir}/hub/bin/skillsgo-hub "* | "${root_dir}/hub/bin/skillsgo-hub")
      return 0
      ;;
    flutter\ * | */flutter\ *)
      [[ "${command}" == *" run "* && "${command}" == *" -d macos"* ]]
      return
      ;;
    dart\ * | */dart\ *)
      [[ "${command}" == *flutter_tools.snapshot*" run "* && "${command}" == *" -d macos"* ]]
      return
      ;;
    "${root_dir}/app/build/macos/"*skillsgo.app/Contents/MacOS/skillsgo*)
      return 0
      ;;
  esac

  return 1
}

is_owned_by_checkout() {
  local pid="$1"
  local command="$2"
  local cwd

  if [[ "${command}" == *"${root_dir}/"* ]]; then
    return 0
  fi

  cwd="$(process_cwd "${pid}" || true)"
  [[ "${cwd}" == "${root_dir}" || "${cwd}" == "${root_dir}/"* ]]
}

contains_pid() {
  local wanted="$1"
  local existing

  for existing in "${target_pids[@]:-}"; do
    if [[ "${existing}" == "${wanted}" ]]; then
      return 0
    fi
  done

  return 1
}

discover_candidates() {
  local pid
  local ppid
  local command

  candidate_pids=()
  process_snapshot="$(ps -axo pid=,ppid=,command=)"
  while read -r pid ppid command; do
    [[ -n "${pid:-}" && -n "${command:-}" ]] || continue
    if is_known_dev_command "${command}" && is_owned_by_checkout "${pid}" "${command}"; then
      candidate_pids+=("${pid}")
    fi
  done <<< "${process_snapshot}"
}

add_process_tree() {
  local parent_pid="$1"
  local pid
  local ppid
  local command

  contains_pid "${parent_pid}" && return 0
  target_pids+=("${parent_pid}")

  while read -r pid ppid command; do
    [[ -n "${pid:-}" && -n "${ppid:-}" ]] || continue
    if [[ "${ppid}" == "${parent_pid}" ]]; then
      add_process_tree "${pid}"
    fi
  done <<< "${process_snapshot}"
}

live_targets() {
  local pid

  for pid in "${target_pids[@]:-}"; do
    if kill -0 "${pid}" 2>/dev/null; then
      printf '%s\n' "${pid}"
    fi
  done
}

remove_stale_flutter_pid_file() {
  local pid

  [[ -e "${flutter_pid_file}" ]] || return 0
  pid="$(<"${flutter_pid_file}")"
  if ! [[ "${pid}" =~ ^[0-9]+$ ]] || ! kill -0 "${pid}" 2>/dev/null; then
    rm -f "${flutter_pid_file}"
  fi
}

discover_candidates
if [[ ${#candidate_pids[@]} -eq 0 ]]; then
  remove_stale_flutter_pid_file
  exit 0
fi

for candidate_pid in "${candidate_pids[@]}"; do
  add_process_tree "${candidate_pid}"
done

if [[ "${dry_run}" == true ]]; then
  echo "Stale SkillsGo development processes: ${target_pids[*]}"
  exit 0
fi

echo "Stopping stale SkillsGo development processes: ${target_pids[*]}"
kill -TERM "${target_pids[@]}" 2>/dev/null || true

deadline=$((SECONDS + grace_seconds))
while [[ "$(live_targets | wc -l | tr -d ' ')" -gt 0 && ${SECONDS} -lt ${deadline} ]]; do
  sleep 0.1
done

remaining_pids=()
while IFS= read -r pid; do
  [[ -n "${pid}" ]] && remaining_pids+=("${pid}")
done < <(live_targets)

if [[ ${#remaining_pids[@]} -gt 0 ]]; then
  echo "Force stopping unresponsive SkillsGo development processes: ${remaining_pids[*]}"
  kill -KILL "${remaining_pids[@]}" 2>/dev/null || true
fi

remove_stale_flutter_pid_file
