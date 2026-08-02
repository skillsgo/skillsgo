#!/usr/bin/env bash
# [INPUT]: Depends on one canonical CLI SemVer, supported GOOS/GOARCH pair, Git commit metadata, Go, tar/zip, and the standalone CLI module graph.
# [OUTPUT]: Builds one metadata-injected standalone binary plus its architecture-specific release archive from GOWORK=off dependencies.
# [POS]: Serves as the unified standalone CLI binary build contract shared by CI candidates and tag releases.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

set -euo pipefail

readonly version="${1:-}"
readonly goos="${2:-}"
readonly goarch="${3:-}"
readonly output_root="${4:-}"
readonly distribution="${5:-direct}"
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Usage: $0 <vX.Y.Z> <darwin|linux|windows> <arm64|amd64> <output-directory> [distribution]" >&2
  exit 64
fi
case "${goos}/${goarch}" in
  darwin/arm64|darwin/amd64|linux/arm64|linux/amd64|windows/amd64) ;;
  *)
    echo "Unsupported CLI release target: ${goos}/${goarch}" >&2
    exit 64
    ;;
esac
if [[ ! "${distribution}" =~ ^[a-z][a-z0-9-]*$ || -z "${output_root}" ]]; then
  echo "Invalid CLI distribution or output directory." >&2
  exit 64
fi

readonly version_number="${version#v}"
readonly package="skillsgo_${version_number}_${goos}_${goarch}"
readonly staging="${output_root}/staging/${package}"
readonly commit="${SKILLSGO_CLI_COMMIT:-$(git -C "${repository_root}" rev-parse HEAD)}"
readonly build_date="${SKILLSGO_CLI_BUILD_DATE:-$(git -C "${repository_root}" show -s --format=%cI "${commit}")}"
binary_name="skillsgo"
archive="${output_root}/${package}.tar.gz"
if [[ "${goos}" == "windows" ]]; then
  binary_name="skillsgo.exe"
  archive="${output_root}/${package}.zip"
fi
readonly binary_name archive
readonly binary="${output_root}/skillsgo-${goos}-${goarch}${binary_name#skillsgo}"

mkdir -p "${staging}" "${output_root}"
(
  cd "${repository_root}/cli"
  CGO_ENABLED=0 GOOS="${goos}" GOARCH="${goarch}" GOWORK=off go build \
    -buildvcs=false \
    -trimpath \
    -ldflags "-s -w -X github.com/skillsgo/skillsgo/cli/internal/buildinfo.version=${version} -X github.com/skillsgo/skillsgo/cli/internal/buildinfo.distribution=${distribution} -X github.com/skillsgo/skillsgo/cli/internal/buildinfo.commit=${commit} -X github.com/skillsgo/skillsgo/cli/internal/buildinfo.buildDate=${build_date}" \
    -o "${binary}" \
    ./cmd/skillsgo
)
cp "${binary}" "${staging}/${binary_name}"
cp "${repository_root}/LICENSE" "${staging}/LICENSE"
chmod 0755 "${staging}/${binary_name}"

if [[ "${goos}" == "windows" ]]; then
  (
    cd "${output_root}/staging"
    zip -X -q -r "${archive}" "${package}"
  )
else
  tar -C "${output_root}/staging" -czf "${archive}" "${package}"
fi
if [[ ! -s "${binary}" || ! -s "${archive}" ]]; then
  echo "CLI build contract did not produce complete outputs for ${goos}/${goarch}." >&2
  exit 1
fi
printf '%s\n' "${archive}"
