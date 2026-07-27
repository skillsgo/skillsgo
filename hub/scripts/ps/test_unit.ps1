# [INPUT]: Depends on the Go toolchain and test environment selection.
# [OUTPUT]: Runs the Hub unit and available integration tests with race detection and coverage.
# [POS]: Serves as the Windows unit-test entry point for the Hub workspace.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

if (!(Test-Path env:SKILLSGO_HUB_ENVIRONMENT)) {$env:SKILLSGO_HUB_ENVIRONMENT = "test"}

$env:GO111MODULE="on"
& go test -mod=vendor -race -coverprofile cover.out -covermode atomic ./...
