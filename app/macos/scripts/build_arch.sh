#!/usr/bin/env bash
# [INPUT]: Depends on Flutter's generated macOS workspace, one supported target architecture, optional release version/update-source overrides, and the bundled-CLI build phase.
# [OUTPUT]: Produces one fully architecture-, version-, and update-source-specific Release SkillsGo.app in an isolated DerivedData directory.
# [POS]: Serves as the canonical macOS arm64/x86_64 App build entry point for local packaging, CI candidates, production releases, and multi-version update rehearsals.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly architecture="${1:-}"
case "${architecture}" in
  arm64|x86_64) ;;
  *)
    echo "Usage: $0 <arm64|x86_64>" >&2
    exit 64
    ;;
esac

readonly app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly derived_data="${SKILLSGO_MACOS_DERIVED_DATA:-${app_root}/build/macos-${architecture}}"
readonly app_bundle="${derived_data}/Build/Products/Release/SkillsGo.app"
readonly code_signing_allowed="${SKILLSGO_MACOS_CODE_SIGNING_ALLOWED:-NO}"

cd "${app_root}"
flutter_build_args=(macos --release --config-only)
if [[ -n "${SKILLSGO_APP_BUILD_NAME:-}" ]]; then
  flutter_build_args+=(--build-name "${SKILLSGO_APP_BUILD_NAME}")
fi
if [[ -n "${SKILLSGO_APP_BUILD_NUMBER:-}" ]]; then
  flutter_build_args+=(--build-number "${SKILLSGO_APP_BUILD_NUMBER}")
fi
if [[ -n "${SKILLSGO_APP_UPDATE_URL:-}" ]]; then
  flutter_build_args+=(--dart-define "SKILLSGO_APP_UPDATE_URL=${SKILLSGO_APP_UPDATE_URL}")
fi
flutter build "${flutter_build_args[@]}"

xcodebuild \
  -quiet \
  -workspace macos/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${derived_data}" \
  ARCHS="${architecture}" \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED="${code_signing_allowed}" \
  build

while IFS= read -r -d '' binary; do
  if [[ "$(file -b "${binary}")" != *"Mach-O"* ]]; then
    continue
  fi
  actual_architectures="$(lipo -archs "${binary}")"
  if [[ "${actual_architectures}" != "${architecture}" ]]; then
    echo "Unexpected architectures in ${binary}: ${actual_architectures}; expected ${architecture}" >&2
    exit 1
  fi
done < <(find "${app_bundle}" -type f -print0)

echo "Built ${app_bundle} for ${architecture}"
