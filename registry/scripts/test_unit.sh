#!/bin/bash

# test_unit.sh

if [ -z ${SKILLSGO_REGISTRY_ENVIRONMENT} ]; then
    export SKILLSGO_REGISTRY_ENVIRONMENT="test"
fi

if [ -z ${SKILLSGO_REGISTRY_MINIO_ENDPOINT} ]; then
    export SKILLSGO_REGISTRY_MINIO_ENDPOINT="http://127.0.0.1:9001"
fi

if [ -z ${SKILLSGO_REGISTRY_MONGO_STORAGE_URL} ]; then
    export SKILLSGO_REGISTRY_MONGO_STORAGE_URL="mongodb://127.0.0.1:27017"
fi

export GO111MODULE=on

# Run the unit tests with the race detector and code coverage enabled
set -xeuo pipefail
go test -race -coverprofile cover.out -covermode atomic ./...
