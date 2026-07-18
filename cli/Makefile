# [INPUT]: Depends on the Go toolchain and the SkillsGo CLI command entry point under cmd/skillsgo.
# [OUTPUT]: Builds the ignored local development binary at bin/skillsgo and removes local build artifacts.
# [POS]: Serves as the CLI workspace's local build entry while release packaging remains repository-level automation.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md

.PHONY: build clean

build: ## build the local SkillsGo CLI binary
	mkdir -p ./bin
	go build -trimpath -o ./bin/skillsgo ./cmd/skillsgo

clean: ## delete local CLI build artifacts
	rm -rf ./bin
