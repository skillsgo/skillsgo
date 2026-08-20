# [INPUT]: Depends on scripts/dev.sh plus the Protocol, CLI, and Hub workspace build and validation entry points.
# [OUTPUT]: Provides unified or Hub-only development sessions plus repository-level builds, unit tests, CLI E2E tests, and formatting commands.
# [POS]: Serves as the monorepo task entry point and delegates product-specific work to each workspace.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

.PHONY: dev dev-hub build build-cli build-hub test test-protocol test-cli test-hub test-e2e test-e2e-cli format-protocol format-cli format-hub

dev:
	./scripts/dev.sh

dev-hub:
	./scripts/dev.sh hub

build: build-cli build-hub

build-cli:
	$(MAKE) -C cli build

build-hub:
	$(MAKE) -C hub build

test: test-protocol test-hub test-cli

test-protocol:
	@coverage_file=$$(mktemp); \
	cd protocol && go test -coverprofile=$$coverage_file ./... && \
	coverage=$$(go tool cover -func=$$coverage_file | awk '/^total:/ { sub(/%/, "", $$3); print $$3 }'); \
	echo "Protocol statement coverage: $$coverage%"; \
	awk "BEGIN { if ($$coverage < 95) exit 1 }"

test-hub:
	cd hub && go test ./...

test-cli:
	cd cli && go test ./...

test-e2e: test-e2e-cli

test-e2e-cli:
	cd e2e/cli && GOWORK=off go tool gotestsum --format standard-verbose -- -count=1 -timeout=15m ./...

format-hub:
	cd hub && gofmt -w $$(find . -name '*.go' -type f)

format-protocol:
	cd protocol && gofmt -w $$(find . -name '*.go' -type f)

format-cli:
	cd cli && gofmt -w $$(find . -name '*.go' -type f)
