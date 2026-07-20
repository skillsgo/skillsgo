# [INPUT]: Depends on scripts/dev.sh plus the App, CLI, Hub, and docs-site workspace build and validation entry points.
# [OUTPUT]: Provides the unified macOS development session plus repository-level local builds, unit tests, docs validation, split CLI/App E2E tests, analysis, and formatting commands.
# [POS]: Serves as the monorepo task entry point and delegates product-specific work to each workspace.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

.PHONY: dev dev-docs build build-cli build-hub build-docs test test-app test-cli test-hub test-docs test-e2e test-e2e-cli test-e2e-app analyze-app format-cli format-hub

dev:
	./scripts/dev.sh

dev-docs:
	cd docs-site && pnpm dev

build: build-cli build-hub build-docs

build-cli:
	$(MAKE) -C cli build

build-hub:
	$(MAKE) -C hub build

build-docs:
	cd docs-site && pnpm build

test: test-hub test-cli test-app test-docs

test-hub:
	cd hub && go test ./...

test-app:
	cd app && flutter test

test-cli:
	cd cli && go test ./...

test-docs:
	cd docs-site && pnpm typecheck

test-e2e: test-e2e-cli test-e2e-app

test-e2e-cli:
	cd e2e/cli && go test -v ./...

test-e2e-app:
	./e2e/app/run.sh

analyze-app:
	cd app && flutter analyze

format-hub:
	cd hub && gofmt -w $$(find . -name '*.go' -type f)

format-cli:
	cd cli && gofmt -w $$(find . -name '*.go' -type f)
