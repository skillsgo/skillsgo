#!/usr/bin/env bash
# [INPUT]: Depends on one native Flutter Release bundle, the matching bundled CLI, the workspace App version, Velopack CLI 1.0.1, and unzip-compatible package inspection.
# [OUTPUT]: Produces and structurally verifies one unsigned Velopack candidate channel for Windows x64, Linux x64, macOS arm64, or macOS x64.
# [POS]: Serves as the deterministic native-build-to-candidate packaging boundary shared by local release rehearsals and GitHub Actions.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly target="${1:-}"
readonly architecture="${2:-}"
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly app_root="${repository_root}/app"
readonly version="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p' "${app_root}/pubspec.yaml")"

if [[ -z "${version}" ]]; then
  echo "Unable to read the App version from app/pubspec.yaml." >&2
  exit 1
fi

case "${target}:${architecture}" in
  windows:x64)
    readonly channel="win-x64"
    readonly runtime="win-x64"
    readonly pack_dir="${app_root}/build/windows/x64/runner/Release"
    readonly main_exe="skillsgo.exe"
    readonly bundled_cli="${pack_dir}/data/bin/skillsgo.exe"
    readonly packaged_main="lib/app/skillsgo.exe"
    readonly packaged_cli="lib/app/data/bin/skillsgo.exe"
    readonly portable_name="SkillsGo-${channel}-Portable.zip"
    readonly installer_name="SkillsGo-${channel}-Setup.exe"
    ;;
  linux:x64)
    readonly channel="linux-x64"
    readonly runtime="linux-x64"
    readonly pack_dir="${app_root}/build/linux/x64/release/bundle"
    readonly main_exe="skillsgo"
    readonly bundled_cli="${pack_dir}/data/bin/skillsgo"
    readonly packaged_main="lib/app/skillsgo"
    readonly packaged_cli="lib/app/data/bin/skillsgo"
    readonly portable_name="SkillsGo-${channel}.AppImage"
    readonly installer_name=""
    ;;
  macos:arm64)
    readonly channel="osx-arm64"
    readonly runtime="osx-arm64"
    readonly pack_dir="${app_root}/build/macos-arm64/Build/Products/Release/SkillsGo.app"
    readonly main_exe="SkillsGo"
    readonly bundled_cli="${pack_dir}/Contents/Resources/bin/skillsgo"
    readonly packaged_main="lib/app/Contents/MacOS/SkillsGo"
    readonly packaged_cli="lib/app/Contents/Resources/bin/skillsgo"
    readonly portable_name="SkillsGo-${channel}-Portable.zip"
    readonly installer_name=""
    ;;
  macos:x86_64)
    readonly channel="osx-x64"
    readonly runtime="osx-x64"
    readonly pack_dir="${app_root}/build/macos-x86_64/Build/Products/Release/SkillsGo.app"
    readonly main_exe="SkillsGo"
    readonly bundled_cli="${pack_dir}/Contents/Resources/bin/skillsgo"
    readonly packaged_main="lib/app/Contents/MacOS/SkillsGo"
    readonly packaged_cli="lib/app/Contents/Resources/bin/skillsgo"
    readonly portable_name="SkillsGo-${channel}-Portable.zip"
    readonly installer_name=""
    ;;
  *)
    echo "Usage: $0 <windows x64|linux x64|macos arm64|macos x86_64>" >&2
    exit 64
    ;;
esac

readonly output_dir="${app_root}/build/velopack/${channel}"
rm -rf "${output_dir}"
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
    ;;
  linux)
    pack_args+=(--icon "${app_root}/linux/runner/resources/skillsgo.png")
    ;;
  macos)
    # An unsigned PKG is not a distributable macOS installer. The free
    # rehearsal deliberately emits only the portable update bundle.
    pack_args+=(--noInst)
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
for package_entry in "${packaged_main}" "${packaged_cli}"; do
  if ! grep -Fxq "${package_entry}" <<<"${package_entries}"; then
    echo "Velopack full package is missing ${package_entry}: ${full_package}" >&2
    exit 1
  fi
done

if [[ -n "${installer_name}" && ! -s "${output_dir}/${installer_name}" ]]; then
  echo "Velopack installer is missing or empty: ${output_dir}/${installer_name}" >&2
  exit 1
fi

cat >"${output_dir}/candidate.json" <<EOF
{"schemaVersion":1,"appId":"SkillsGo","version":"${version}","channel":"${channel}","runtime":"${runtime}","signed":false}
EOF

echo "Packaged unsigned SkillsGo ${version} candidate for ${channel}: ${output_dir}"
