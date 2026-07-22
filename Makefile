# [INPUT]: Depends on scripts/dev.sh plus the Protocol, App, CLI, Hub, and Web workspace build and validation entry points.
# [OUTPUT]: Provides the unified macOS development session plus repository-level local builds, unit tests, docs validation, split CLI/App E2E tests, analysis, and formatting commands.
# [POS]: Serves as the monorepo task entry point and delegates product-specific work to each workspace.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

.PHONY: dev dev-web dev-docs build build-cli build-hub build-web build-docs test test-protocol test-app test-cli test-hub test-web test-docs test-e2e test-e2e-cli test-e2e-app analyze-app format-protocol format-cli format-hub

dev:
	./scripts/dev.sh

dev-web:
	cd web && pnpm dev

dev-docs: dev-web

build: build-cli build-hub build-web

build-cli:
	$(MAKE) -C cli build

build-hub:
	$(MAKE) -C hub build

build-web:
	cd web && pnpm build

build-docs: build-web

test: test-protocol test-hub test-cli test-app test-web

test-protocol:
	@coverage_file=$$(mktemp); \
	cd protocol && go test -coverprofile=$$coverage_file ./... && \
	coverage=$$(go tool cover -func=$$coverage_file | awk '/^total:/ { sub(/%/, "", $$3); print $$3 }'); \
	echo "Protocol statement coverage: $$coverage%"; \
	awk "BEGIN { if ($$coverage < 95) exit 1 }"

test-hub:
	cd hub && go test ./...

test-app:
	cd app && flutter test

test-cli:
	cd cli && go test ./...

test-web:
	cd web && pnpm typecheck

test-docs: test-web

test-e2e: test-e2e-cli test-e2e-app

test-e2e-cli:
	cd e2e/cli && GOWORK=off go test -v -count=1 ./...

test-e2e-app:
	./e2e/app/run.sh

analyze-app:
	cd app && flutter analyze

format-hub:
	cd hub && gofmt -w $$(find . -name '*.go' -type f)

format-protocol:
	cd protocol && gofmt -w $$(find . -name '*.go' -type f)

format-cli:
	cd cli && gofmt -w $$(find . -name '*.go' -type f)
