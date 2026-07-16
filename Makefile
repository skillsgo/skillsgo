# [INPUT]: Depends on the build, deployment, or runtime values declared in Makefile.\n# [OUTPUT]: Provides the SkillsGo Hub or monorepo configuration defined by Makefile.\n# [POS]: Serves as maintained configuration in the renamed SkillsGo Hub workspace or its repository integration.\n# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md\n.PHONY: test test-app test-cli test-hub analyze-app format-cli format-hub

test: test-hub test-cli test-app

test-hub:
	cd hub && go test ./...

test-app:
	cd app && flutter test

test-cli:
	cd cli && go test ./...

analyze-app:
	cd app && flutter analyze

format-hub:
	cd hub && gofmt -w $$(find . -name '*.go' -type f)

format-cli:
	cd cli && gofmt -w $$(find . -name '*.go' -type f)
