# [INPUT]: Depends on the Go toolchain, GOWORK-independent module dependencies, and the SkillsGo CLI command entry point under cmd/skillsgo.
# [OUTPUT]: Builds the ignored local development binary, verifies standalone module resolution, and removes local build artifacts.
# [POS]: Serves as the CLI workspace's local build entry while repository scripts own release packaging.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

.PHONY: build build-standalone clean

build: ## build the local SkillsGo CLI binary
	mkdir -p ./bin
	go build -trimpath -o ./bin/skillsgo ./cmd/skillsgo

build-standalone: ## prove the CLI builds without the repository go.work
	mkdir -p ./bin
	GOWORK=off go build -trimpath -o ./bin/skillsgo ./cmd/skillsgo

clean: ## delete local CLI build artifacts
	rm -rf ./bin
