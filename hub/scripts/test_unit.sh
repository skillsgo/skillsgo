#!/bin/bash
# [INPUT]: Depends on the build, deployment, or runtime values declared in test_unit.sh.\n# [OUTPUT]: Provides the SkillsGo Hub or monorepo configuration defined by test_unit.sh.\n# [POS]: Serves as maintained configuration in the renamed SkillsGo Hub workspace or its repository integration.\n# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md\n
# test_unit.sh

if [ -z ${SKILLSGO_HUB_ENVIRONMENT} ]; then
    export SKILLSGO_HUB_ENVIRONMENT="test"
fi

if [ -z ${SKILLSGO_HUB_MINIO_ENDPOINT} ]; then
    export SKILLSGO_HUB_MINIO_ENDPOINT="http://127.0.0.1:9001"
fi

if [ -z ${SKILLSGO_HUB_MONGO_STORAGE_URL} ]; then
    export SKILLSGO_HUB_MONGO_STORAGE_URL="mongodb://127.0.0.1:27017"
fi

export GO111MODULE=on

# Run the unit tests with the race detector and code coverage enabled
set -xeuo pipefail
go test -race -coverprofile cover.out -covermode atomic ./...
