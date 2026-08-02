#!/usr/bin/env bash
# [INPUT]: Depends on build-cli-release.sh, the host Linux/amd64 runtime, tar, JSON grep, and temporary filesystem space.
# [OUTPUT]: Proves standalone CLI archives are GOWORK-independent and carry exact version, distribution, commit, and build-date metadata.
# [POS]: Serves as the black-box regression test for the unified CLI binary build contract.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

if [[ "$(go env GOOS)/$(go env GOARCH)" != "linux/amd64" ]]; then
  echo "Skipping executable CLI build-contract smoke outside linux/amd64."
  exit 0
fi
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly test_root="$(mktemp -d "${TMPDIR:-/tmp}/skillsgo-cli-release-test.XXXXXX")"
trap 'chmod -R u+w "${test_root}"; rm -rf "${test_root}"' EXIT
readonly commit="$(git -C "${repository_root}" rev-parse HEAD)"
readonly build_date="2026-08-02T00:00:00Z"

SKILLSGO_CLI_COMMIT="${commit}" SKILLSGO_CLI_BUILD_DATE="${build_date}" \
  "${repository_root}/scripts/build-cli-release.sh" v1.2.3 linux amd64 "${test_root}/dist" direct >/dev/null
readonly archive="${test_root}/dist/skillsgo_1.2.3_linux_amd64.tar.gz"
tar -xzf "${archive}" -C "${test_root}"
readonly cli="${test_root}/skillsgo_1.2.3_linux_amd64/skillsgo"
readonly handshake="$("${cli}" version --output json)"

for expected in \
  '"version":"v1.2.3"' \
  '"distribution":"direct"' \
  "\"commit\":\"${commit}\"" \
  "\"buildDate\":\"${build_date}\""; do
  if [[ "${handshake}" != *"${expected}"* ]]; then
    echo "Standalone CLI handshake is missing ${expected}: ${handshake}" >&2
    exit 1
  fi
done
if [[ ! -s "${test_root}/skillsgo_1.2.3_linux_amd64/LICENSE" ]]; then
  echo "Standalone CLI archive does not include LICENSE." >&2
  exit 1
fi
echo "CLI release build contract passed."
