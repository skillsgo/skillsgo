# [INPUT]: Depends on scripts/dev.sh plus the Protocol, CLI, and Hub workspace build and validation entry points.
# [OUTPUT]: Provides unified or Hub-only development sessions plus repository-level builds, unit tests, CLI E2E tests, and formatting commands.
# [POS]: Serves as the monorepo task entry point and delegates product-specific work to each workspace.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

.PHONY: dev dev-hub dev-app app-deps build build-cli build-hub build-app-macos build-app-macos-arm64 build-app-macos-x86_64 test test-protocol test-cli test-hub test-app test-e2e test-e2e-cli test-e2e-app check-app format-protocol format-cli format-hub

dev:
	./scripts/dev.sh

dev-hub:
	./scripts/dev.sh hub

app-deps:
	cd app && flutter pub get

dev-app: app-deps
	cd app && flutter run -d macos

build: build-cli build-hub

build-cli:
	$(MAKE) -C cli build

build-hub:
	$(MAKE) -C hub build

build-app-macos: build-app-macos-arm64 build-app-macos-x86_64

build-app-macos-arm64: app-deps
	./app/macos/scripts/build_arch.sh arm64

build-app-macos-x86_64: app-deps
	./app/macos/scripts/build_arch.sh x86_64

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

test-app: app-deps
	cd app && flutter test

check-app: app-deps
	bash -n app/macos/scripts/build_arch.sh app/macos/scripts/bundle_skillsgo_cli.sh e2e/app/run.sh scripts/collect-app-release-downloads.sh scripts/package-app-candidate.sh scripts/prepare-app-update-rehearsal.sh scripts/smoke-app-candidate.sh scripts/smoke-app-update-rehearsal.sh scripts/test-app-update-build-config.sh scripts/test-collect-app-release-downloads.sh
	cd app && flutter analyze

test-e2e: test-e2e-cli test-e2e-app

test-e2e-cli:
	cd e2e/cli && GOWORK=off go tool gotestsum --format standard-verbose -- -count=1 -timeout=15m ./...

test-e2e-app: app-deps
	./e2e/app/run.sh

format-hub:
	cd hub && gofmt -w $$(find . -name '*.go' -type f)

format-protocol:
	cd protocol && gofmt -w $$(find . -name '*.go' -type f)

format-cli:
	cd cli && gofmt -w $$(find . -name '*.go' -type f)
