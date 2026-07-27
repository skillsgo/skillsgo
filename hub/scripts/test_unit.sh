#!/bin/bash
# [INPUT]: Depends on the Go toolchain and test environment selection.
# [OUTPUT]: Runs the Hub unit and available integration tests with race detection and coverage.
# [POS]: Serves as the Unix unit-test entry point for the Hub workspace.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
if [ -z ${SKILLSGO_HUB_ENVIRONMENT} ]; then
    export SKILLSGO_HUB_ENVIRONMENT="test"
fi

export GO111MODULE=on

# Run the unit tests with the race detector and code coverage enabled
set -xeuo pipefail
go test -race -coverprofile cover.out -covermode atomic ./...
