.PHONY: test test-app test-cli test-registry analyze-app format-cli format-registry

test: test-registry test-cli test-app

test-registry:
	cd registry && go test ./...

test-app:
	cd app && flutter test

test-cli:
	cd cli && go test ./...

analyze-app:
	cd app && flutter analyze

format-registry:
	cd registry && gofmt -w $$(find . -name '*.go' -type f)

format-cli:
	cd cli && gofmt -w $$(find . -name '*.go' -type f)
