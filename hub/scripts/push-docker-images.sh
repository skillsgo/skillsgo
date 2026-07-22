#!/bin/bash
# [INPUT]: Depends on Git release metadata, the repository Go workspace, and authenticated Docker registry access.
# [OUTPUT]: Builds and publishes immutable plus channel-tagged SkillsGo Hub container images.
# [POS]: Serves as the legacy command-line publication adapter for the Hub production Dockerfile.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
# Push our docker images to a hub
set -xeuo pipefail

REGISTRY=${REGISTRY:-gomods/}
TAG=$(git describe --tags --exact-match 2> /dev/null || true)
COMMIT=$(git rev-parse --short=7 HEAD)
VERSION=${VERSION:-${TAG:-${COMMIT}}}
BRANCH=${BRANCH:-$(git symbolic-ref -q --short HEAD || echo "")}

# MUTABLE_TAG is the docker image tag that we will reuse between pushes, it is not an immutable tag like a commit hash or tag.
if [[ "${MUTABLE_TAG:-}" == "" ]]; then
    # tagged builds
    if [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        MUTABLE_TAG="latest"
    # main branch build
    elif [[ "$BRANCH" == "main" ]]; then
        MUTABLE_TAG="canary"
    # branch build
    else
        MUTABLE_TAG=${BRANCH}
    fi
fi

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." >/dev/null && pwd )/"

docker build --build-arg VERSION=${VERSION} -t ${REGISTRY}skillsgo-hub:${VERSION} -f ${REPO_ROOT}hub/cmd/skillsgo-hub/Dockerfile ${REPO_ROOT}

# Apply the mutable tag to the immutable version
docker tag ${REGISTRY}skillsgo-hub:${VERSION} ${REGISTRY}skillsgo-hub:${MUTABLE_TAG}

docker push ${REGISTRY}skillsgo-hub:${VERSION}
docker push ${REGISTRY}skillsgo-hub:${MUTABLE_TAG}
