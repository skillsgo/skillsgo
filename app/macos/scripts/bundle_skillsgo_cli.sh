#!/usr/bin/env bash
# [INPUT]: Xcode build paths, target architectures, the CLI Go module, and an installed Go toolchain.
# [OUTPUT]: Builds, verifies, and signs the platform-compatible SkillsGo CLI inside the App Resources directory.
# [POS]: Serves as the macOS packaging bridge that keeps the App and its local mutation engine version-aligned.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly cli_root="${SRCROOT}/../../cli"
readonly destination="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/bin/skillsgo"
readonly app_version="${FLUTTER_BUILD_NAME:-${MARKETING_VERSION:-dev}}"

go_binary="${GO_BINARY:-}"
if [[ -z "${go_binary}" ]]; then
  go_binary="$(command -v go || true)"
fi
if [[ -z "${go_binary}" ]]; then
  for candidate in /opt/homebrew/bin/go /usr/local/go/bin/go /usr/local/bin/go; do
    if [[ -x "${candidate}" ]]; then
      go_binary="${candidate}"
      break
    fi
  done
fi
if [[ -z "${go_binary}" || ! -x "${go_binary}" ]]; then
  echo "error: Go is required to bundle the SkillsGo CLI." >&2
  exit 1
fi

work_directory="$(mktemp -d "${TMPDIR:-/tmp}/skillsgo-cli.XXXXXX")"
trap 'rm -rf "${work_directory}"' EXIT

architectures=(${ARCHS:-$(uname -m)})
binaries=()
for architecture in "${architectures[@]}"; do
  case "${architecture}" in
    arm64) go_architecture="arm64" ;;
    x86_64) go_architecture="amd64" ;;
    *)
      echo "error: Unsupported macOS architecture: ${architecture}" >&2
      exit 1
      ;;
  esac

  binary="${work_directory}/skillsgo-${architecture}"
  (
    cd "${cli_root}"
    CGO_ENABLED=0 GOOS=darwin GOARCH="${go_architecture}" "${go_binary}" build \
      -trimpath \
      -ldflags "-s -w -X github.com/skillsgo/skillsgo/cli/internal/command.version=${app_version}" \
      -o "${binary}" \
      ./cmd/skillsgo
  )
  binaries+=("${binary}")
done

mkdir -p "$(dirname "${destination}")"
if [[ "${#binaries[@]}" -eq 1 ]]; then
  cp "${binaries[0]}" "${destination}"
else
  /usr/bin/lipo -create "${binaries[@]}" -output "${destination}"
fi
chmod 0755 "${destination}"

handshake="$("${destination}" version --output json)"
if [[ "${handshake}" != *"\"version\":\"${app_version}\""* ]]; then
  echo "error: Bundled SkillsGo CLI version does not match App version ${app_version}." >&2
  exit 1
fi

signing_identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
if [[ "${signing_identity}" == "-" ]]; then
  /usr/bin/codesign --force --sign "${signing_identity}" --options runtime --timestamp=none "${destination}"
else
  /usr/bin/codesign --force --sign "${signing_identity}" --options runtime --timestamp "${destination}"
fi
