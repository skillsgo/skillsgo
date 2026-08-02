#!/usr/bin/env bash
# [INPUT]: Depends on four verified architecture-specific Velopack release directories produced by the App release build matrix.
# [OUTPUT]: Collects one user-facing installer per supported platform and architecture, labeling unsigned Windows and macOS packages explicitly, then writes SHA-256 checksums.
# [POS]: Serves as the deterministic release-channel-to-GitHub-assets boundary used by the tag-only App release workflow.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly release_assets_root="${1:-}"
readonly release_downloads_dir="${2:-}"

if [[ -z "${release_assets_root}" || -z "${release_downloads_dir}" ]]; then
  echo "Usage: $0 <release-assets-root> <release-downloads-dir>" >&2
  exit 64
fi

if [[ ! -d "${release_assets_root}" ]]; then
  echo "Release assets root does not exist: ${release_assets_root}" >&2
  exit 1
fi

if [[ -e "${release_downloads_dir}" ]]; then
  echo "Release downloads destination already exists: ${release_downloads_dir}" >&2
  exit 1
fi
mkdir -p "${release_downloads_dir}"

copy_exactly_one() {
  local label="$1"
  local destination_name="$2"
  shift 2
  local -a matches=("$@")

  if [[ "${#matches[@]}" -ne 1 ]]; then
    echo "Expected exactly one non-empty ${label}; found ${#matches[@]}." >&2
    exit 1
  fi
  if [[ ! -s "${matches[0]}" ]]; then
    echo "Expected a non-empty ${label}: ${matches[0]}" >&2
    exit 1
  fi
  cp "${matches[0]}" "${release_downloads_dir}/${destination_name}"
}

channel_is_signed() {
  local channel="$1"
  local channel_dir="${release_assets_root}/${channel}"
  local -a metadata_files=()
  shopt -s nullglob
  metadata_files=("${channel_dir}"/release-*.json)
  shopt -u nullglob

  if [[ "${#metadata_files[@]}" -ne 1 || ! -s "${metadata_files[0]:-missing}" ]]; then
    echo "Expected exactly one release metadata file for ${channel}; found ${#metadata_files[@]}." >&2
    exit 1
  fi
  if grep -Fq '"signed":true' "${metadata_files[0]}"; then
    echo true
    return
  fi
  if grep -Fq '"signed":false' "${metadata_files[0]}"; then
    echo false
    return
  fi
  echo "Release metadata does not declare signing state: ${metadata_files[0]}" >&2
  exit 1
}

shopt -s nullglob
windows_installers=("${release_assets_root}/win-x64"/*-Setup.exe)
linux_installers=("${release_assets_root}/linux-x64"/*.AppImage)
macos_arm_installers=("${release_assets_root}/osx-arm64"/*.pkg)
macos_x64_installers=("${release_assets_root}/osx-x64"/*.pkg)
shopt -u nullglob

readonly windows_signed="$(channel_is_signed win-x64)"
readonly macos_arm_signed="$(channel_is_signed osx-arm64)"
readonly macos_x64_signed="$(channel_is_signed osx-x64)"

if [[ "${windows_signed}" == "true" ]]; then
  windows_download_name="$(basename "${windows_installers[0]:-missing}")"
else
  windows_download_name="SkillsGo-Windows-x64-unsigned-Setup.exe"
fi
copy_exactly_one "Windows x64 installer" "${windows_download_name}" "${windows_installers[@]}"
copy_exactly_one "Linux x64 AppImage" "$(basename "${linux_installers[0]:-missing}")" "${linux_installers[@]}"

if [[ "${macos_arm_signed}" == "true" && "${macos_x64_signed}" == "true" ]]; then
  copy_exactly_one "signed macOS arm64 installer" "$(basename "${macos_arm_installers[0]:-missing}")" "${macos_arm_installers[@]}"
  copy_exactly_one "signed macOS x64 installer" "$(basename "${macos_x64_installers[0]:-missing}")" "${macos_x64_installers[@]}"
elif [[ "${macos_arm_signed}" == "false" && "${macos_x64_signed}" == "false" ]]; then
  copy_exactly_one \
    "unsigned macOS arm64 installer" \
    "SkillsGo-macOS-arm64-unsigned.pkg" \
    "${macos_arm_installers[@]}"
  copy_exactly_one \
    "unsigned macOS x64 installer" \
    "SkillsGo-macOS-x64-unsigned.pkg" \
    "${macos_x64_installers[@]}"
else
  echo "macOS arm64 and x64 channels must use the same signing mode." >&2
  exit 1
fi

(
  cd "${release_downloads_dir}"
  shopt -s nullglob
  downloads=(*-Setup.exe *.AppImage *.pkg *.zip)
  shopt -u nullglob
  for download in "${downloads[@]}"; do
    sha256sum "${download}"
  done >checksums.txt
)

shopt -s nullglob
release_downloads=("${release_downloads_dir}"/*-Setup.exe "${release_downloads_dir}"/*.AppImage "${release_downloads_dir}"/*.pkg "${release_downloads_dir}"/*.zip)
shopt -u nullglob
readonly download_count="${#release_downloads[@]}"
if [[ "${download_count}" != "4" ]]; then
  echo "Expected four user-facing App downloads; found ${download_count}." >&2
  exit 1
fi

echo "Collected four App downloads in ${release_downloads_dir}."
