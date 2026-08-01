#!/usr/bin/env bash
# [INPUT]: Depends on one native Flutter Release bundle, the matching bundled CLI, a workspace or explicit App version, Velopack CLI 1.2.0, optional prior channel packages, and optional release-mode signing/notarization credentials.
# [OUTPUT]: Produces and verifies one platform-layout-aware Velopack candidate or production channel for Windows x64, Linux x64, macOS arm64, or macOS x64, optionally appending a version to an existing feed.
# [POS]: Serves as the deterministic native-build-to-Velopack boundary shared by local rehearsals, candidate CI, and protected production release automation.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly target="${1:-}"
readonly architecture="${2:-}"
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly app_root="${repository_root}/app"
readonly workspace_version="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' "${app_root}/pubspec.yaml")"
readonly version="${SKILLSGO_APP_PACKAGE_VERSION:-${workspace_version}}"
readonly append_to_feed="${SKILLSGO_APP_PACKAGE_APPEND:-0}"
readonly package_mode="${SKILLSGO_APP_PACKAGE_MODE:-candidate}"

if [[ -z "${version}" ]]; then
  echo "Unable to read the App version from app/pubspec.yaml." >&2
  exit 1
fi
if [[ "${package_mode}" != "candidate" && "${package_mode}" != "release" ]]; then
  echo "SKILLSGO_APP_PACKAGE_MODE must be candidate or release." >&2
  exit 64
fi
case "${target}:${architecture}" in
  windows:x64)
    readonly channel="win-x64"
    readonly runtime="win-x64"
    readonly pack_dir="${app_root}/build/windows/x64/runner/Release"
    readonly main_exe="skillsgo.exe"
    readonly bundled_cli="${pack_dir}/data/bin/skillsgo.exe"
    readonly -a packaged_entries=(
      "lib/app/skillsgo.exe"
      "lib/app/data/bin/skillsgo.exe")
    readonly portable_name="SkillsGo-${channel}-Portable.zip"
    readonly installer_name="SkillsGo-${channel}-Setup.exe"
    ;;
  linux:x64)
    readonly channel="linux-x64"
    readonly runtime="linux-x64"
    readonly pack_dir="${app_root}/build/linux/x64/release/bundle"
    readonly main_exe="skillsgo"
    readonly bundled_cli="${pack_dir}/data/bin/skillsgo"
    # Velopack's official Linux release builder places the complete AppImage,
    # rather than the expanded AppDir, inside the full update package.
    readonly -a packaged_entries=("lib/app/SkillsGo.AppImage")
    readonly portable_name="SkillsGo-${channel}.AppImage"
    readonly installer_name=""
    ;;
  macos:arm64)
    readonly channel="osx-arm64"
    readonly runtime="osx-arm64"
    readonly macos_derived_data="${SKILLSGO_MACOS_DERIVED_DATA:-${app_root}/build/macos-arm64}"
    readonly pack_dir="${macos_derived_data}/Build/Products/Release/SkillsGo.app"
    readonly main_exe="SkillsGo"
    readonly bundled_cli="${pack_dir}/Contents/Resources/bin/skillsgo"
    readonly -a packaged_entries=(
      "lib/app/Contents/MacOS/SkillsGo"
      "lib/app/Contents/Resources/bin/skillsgo")
    readonly portable_name="SkillsGo-${channel}-Portable.zip"
    readonly installer_name=""
    ;;
  macos:x86_64)
    readonly channel="osx-x64"
    readonly runtime="osx-x64"
    readonly macos_derived_data="${SKILLSGO_MACOS_DERIVED_DATA:-${app_root}/build/macos-x86_64}"
    readonly pack_dir="${macos_derived_data}/Build/Products/Release/SkillsGo.app"
    readonly main_exe="SkillsGo"
    readonly bundled_cli="${pack_dir}/Contents/Resources/bin/skillsgo"
    readonly -a packaged_entries=(
      "lib/app/Contents/MacOS/SkillsGo"
      "lib/app/Contents/Resources/bin/skillsgo")
    readonly portable_name="SkillsGo-${channel}-Portable.zip"
    readonly installer_name=""
    ;;
  *)
    echo "Usage: $0 <windows x64|linux x64|macos arm64|macos x86_64>" >&2
    exit 64
    ;;
esac

readonly output_dir="${app_root}/build/velopack/${channel}"
if [[ "${append_to_feed}" != "1" ]]; then
  rm -rf "${output_dir}"
fi
mkdir -p "${output_dir}"

if [[ ! -x "${bundled_cli}" ]]; then
  echo "Bundled CLI is missing or not executable: ${bundled_cli}" >&2
  exit 1
fi

pack_args=(
  pack
  --packId SkillsGo
  --packTitle SkillsGo
  --packAuthors SkillsGo
  --packVersion "${version}"
  --packDir "${pack_dir}"
  --mainExe "${main_exe}"
  --runtime "${runtime}"
  --channel "${channel}"
  --outputDir "${output_dir}"
  --delta None)

case "${target}" in
  windows)
    pack_args+=(--icon "${app_root}/windows/runner/resources/app_icon.ico")
    if [[ "${package_mode}" == "release" && -n "${SKILLSGO_WINDOWS_SIGN_PARAMS:-}" ]]; then
      : "${SKILLSGO_WINDOWS_SIGN_PARAMS:?SKILLSGO_WINDOWS_SIGN_PARAMS is required for a Windows release}"
      pack_args+=(--signParams "${SKILLSGO_WINDOWS_SIGN_PARAMS}")
    fi
    ;;
  linux)
    pack_args+=(--icon "${app_root}/linux/runner/resources/skillsgo.png")
    ;;
  macos)
    if [[ "${package_mode}" == "release" && -n "${SKILLSGO_MACOS_SIGN_APP_IDENTITY:-}" && -n "${SKILLSGO_MACOS_SIGN_INSTALL_IDENTITY:-}" && -n "${SKILLSGO_MACOS_NOTARY_PROFILE:-}" && -n "${SKILLSGO_MACOS_KEYCHAIN:-}" ]]; then
      : "${SKILLSGO_MACOS_SIGN_APP_IDENTITY:?SKILLSGO_MACOS_SIGN_APP_IDENTITY is required for a macOS release}"
      : "${SKILLSGO_MACOS_SIGN_INSTALL_IDENTITY:?SKILLSGO_MACOS_SIGN_INSTALL_IDENTITY is required for a macOS release}"
      : "${SKILLSGO_MACOS_NOTARY_PROFILE:?SKILLSGO_MACOS_NOTARY_PROFILE is required for a macOS release}"
      : "${SKILLSGO_MACOS_KEYCHAIN:?SKILLSGO_MACOS_KEYCHAIN is required for a macOS release}"
      pack_args+=(
        --signAppIdentity "${SKILLSGO_MACOS_SIGN_APP_IDENTITY}"
        --signInstallIdentity "${SKILLSGO_MACOS_SIGN_INSTALL_IDENTITY}"
        --notaryProfile "${SKILLSGO_MACOS_NOTARY_PROFILE}"
        --keychain "${SKILLSGO_MACOS_KEYCHAIN}")
    else
      # An unsigned PKG is not a distributable macOS installer. Candidate
      # rehearsals deliberately emit only the portable update bundle.
      pack_args+=(--noInst)
    fi
    ;;
esac

vpk "${pack_args[@]}"

readonly release_manifest="${output_dir}/releases.${channel}.json"
readonly full_package="${output_dir}/SkillsGo-${version}-${channel}-full.nupkg"
readonly portable="${output_dir}/${portable_name}"

for artifact in "${release_manifest}" "${full_package}" "${portable}"; do
  if [[ ! -s "${artifact}" ]]; then
    echo "Velopack candidate artifact is missing or empty: ${artifact}" >&2
    exit 1
  fi
done

for manifest_field in \
  "\"PackageId\":\"SkillsGo\"" \
  "\"Version\":\"${version}\"" \
  "\"Type\":\"Full\"" \
  "\"FileName\":\"$(basename "${full_package}")\""; do
  if ! grep -Fq "${manifest_field}" "${release_manifest}"; then
    echo "Velopack release manifest is missing ${manifest_field}: ${release_manifest}" >&2
    exit 1
  fi
done

readonly package_entries="$(unzip -Z1 "${full_package}")"
for package_entry in "${packaged_entries[@]}"; do
  if ! grep -Fxq "${package_entry}" <<<"${package_entries}"; then
    echo "Velopack full package is missing ${package_entry}: ${full_package}" >&2
    exit 1
  fi
done

if [[ -n "${installer_name}" && ! -s "${output_dir}/${installer_name}" ]]; then
  echo "Velopack installer is missing or empty: ${output_dir}/${installer_name}" >&2
  exit 1
fi
if [[ "${target}" == "macos" && "${package_mode}" == "release" && -n "${SKILLSGO_MACOS_SIGN_APP_IDENTITY:-}" && -n "${SKILLSGO_MACOS_SIGN_INSTALL_IDENTITY:-}" && -n "${SKILLSGO_MACOS_NOTARY_PROFILE:-}" && -n "${SKILLSGO_MACOS_KEYCHAIN:-}" ]]; then
  shopt -s nullglob
  macos_installers=("${output_dir}"/*.pkg)
  shopt -u nullglob
  if [[ "${#macos_installers[@]}" -ne 1 || ! -s "${macos_installers[0]}" ]]; then
    echo "Expected exactly one signed macOS PKG in ${output_dir}." >&2
    exit 1
  fi
  pkgutil --check-signature "${macos_installers[0]}"
  xcrun stapler validate "${macos_installers[0]}"
fi

readonly metadata_name="$([[ "${package_mode}" == "release" ]] && echo "release-${version}" || echo candidate)"
signed=false
if [[ "${package_mode}" == "release" ]]; then
  case "${target}" in
    windows)
      [[ -n "${SKILLSGO_WINDOWS_SIGN_PARAMS:-}" ]] && signed=true
      ;;
    macos)
      if [[ -n "${SKILLSGO_MACOS_SIGN_APP_IDENTITY:-}" && -n "${SKILLSGO_MACOS_SIGN_INSTALL_IDENTITY:-}" && -n "${SKILLSGO_MACOS_NOTARY_PROFILE:-}" && -n "${SKILLSGO_MACOS_KEYCHAIN:-}" ]]; then
        signed=true
      fi
      ;;
  esac
fi
cat >"${output_dir}/${metadata_name}.json" <<EOF
{"schemaVersion":1,"appId":"SkillsGo","version":"${version}","channel":"${channel}","runtime":"${runtime}","mode":"${package_mode}","signed":${signed}}
EOF

echo "Packaged SkillsGo ${version} ${package_mode} for ${channel}: ${output_dir}"
