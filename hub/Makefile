# [INPUT]: Depends on Go tooling, Docker, and repository scripts for Hub build, test, and development workflows.
# [OUTPUT]: Provides maintained build, test, image, and local-development targets for the SkillsGo Hub.
# [POS]: Serves as the Hub workspace command entry point alongside the repository-level Makefile.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
VERSION = "unset"
DATE=$(shell date -u +%Y-%m-%d-%H:%M:%S-%Z)

GOLANGCI_LINT_VERSION=v2.11.4

ifndef GOLANG_VERSION
override GOLANG_VERSION = 1.26.2
endif

.PHONY: build
build: ## build the SkillsGo Hub
	mkdir -p ./bin
	go build -ldflags="-w -s" -o ./bin/skillsgo-hub ./cmd/skillsgo-hub

.PHONY: build-ver
build-ver: ## build the SkillsGo Hub with version number
	mkdir -p ./bin
	GO111MODULE=on CGO_ENABLED=0 GOPROXY="https://proxy.golang.org" go build -ldflags "-s -w -X github.com/skillsgo/skillsgo/hub/pkg/build.version=$(VERSION) -X github.com/skillsgo/skillsgo/hub/pkg/build.buildDate=$(DATE)" -o ./bin/skillsgo-hub ./cmd/skillsgo-hub

skillsgo-hub:
	$(MAKE) build-ver

# The build-image step creates a docker image that has all the tools required
# to perform some CI build steps, instead of relying on them being installed locally
.PHONY: build-image
build-image:
	docker build -t athens-build --build-arg GOLANG_VERSION=${GOLANG_VERSION} ./scripts/build-image

.PHONY: run
run: ## run the SkillsGo Hub with dev configs
	cd ./cmd/skillsgo-hub && go run . -config_file ../../config.dev.toml

.PHONY: run-docker
run-docker:
	docker-compose -p athensdockerdev build --build-arg GOLANG_VERSION=${GOLANG_VERSION} dev
	docker-compose -p athensdockerdev up -d dev

.PHONY: run-docker-teardown
run-docker-teardown:
	docker-compose -p athensdockerdev down

.PHONY: setup-dev-env
setup-dev-env:
	$(MAKE) dev

.PHONY: lint
lint:
	@golangci-lint run ./...

.PHONY: lint-docker
lint-docker:
	@docker run -t --rm -v $(CURDIR):/app -w /app golangci/golangci-lint:$(GOLANGCI_LINT_VERSION) golangci-lint run ./...

.PHONY: verify
verify: ## verify athens codebase
	./scripts/check_deps.sh
	./scripts/check_conflicts.sh

.PHONY: test-unit
test-unit: ## run unit tests with race detector and code coverage enabled
	./scripts/test_unit.sh

.PHONY: test-unit-docker
test-unit-docker: ## run unit tests with docker
	docker-compose -p athensunit build --build-arg GOLANG_VERSION=${GOLANG_VERSION} testunit
	docker-compose -p athensunit up --exit-code-from=testunit testunit
	docker-compose -p athensunit down

.PHONY: test-e2e
test-e2e:
	./scripts/test_e2e.sh

.PHONY: test-e2e-docker
test-e2e-docker:
	docker-compose -p athense2e build --build-arg GOLANG_VERSION=${GOLANG_VERSION} teste2e
	docker-compose -p athense2e up --exit-code-from=teste2e teste2e
	docker-compose -p athense2e down

.PHONY: docker
docker: hub-docker

.PHONY: hub-docker
hub-docker:
	docker build -t skillsgo/hub -f hub/cmd/skillsgo-hub/Dockerfile --build-arg GOLANG_VERSION=${GOLANG_VERSION} ..

.PHONY: docker-push
docker-push:
	./scripts/push-docker-images.sh

bench:
	./scripts/benchmark.sh

.PHONY: alldeps
alldeps:
	docker-compose -p athensdev up -d mongo
	docker-compose -p athensdev up -d minio
	docker-compose -p athensdev up -d jaeger
	echo "sleeping for a bit to wait for the DB to come up"
	sleep 5

.PHONY: dev
dev:
	docker-compose -p athensdev up -d mongo
	docker-compose -p athensdev up -d minio

.PHONY: down
down:
	docker-compose -p athensdev down -v

.PHONY: dev-teardown
dev-teardown:
	docker-compose -p athensdev down -v

.PHONY: clean
clean: ## delete all locally-built artefacts (not including docker images)
	rm -rf ./bin

.PHONY: help
help: ## display help page
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: deploy-gae
deploy-gae:
	cd scripts/gae && gcloud app deploy
