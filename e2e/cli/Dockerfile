# [INPUT]: Depends on the repository Go workspace, Protocol, CLI, Hub, and E2E Cloud Mock modules plus the container entrypoint.
# [OUTPUT]: Produces one reusable Linux image containing real CLI/Hub binaries, the test-only Cloud process, and runtime VCS tools.
# [POS]: Serves as the disposable single-container runtime for every cross-product e2e scenario.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ARG GO_VERSION=1.26.5

FROM golang:${GO_VERSION}-alpine AS cli-builder
WORKDIR /src
COPY go.work go.work.sum ./
COPY cli/go.mod cli/go.sum ./cli/
COPY hub/go.mod hub/go.sum ./hub/
COPY protocol/go.mod ./protocol/
RUN cd cli && go mod download
COPY cli/ ./cli/
COPY protocol/ ./protocol/
RUN cd cli && CGO_ENABLED=0 go build -trimpath -o /out/skillsgo ./cmd/skillsgo

FROM golang:${GO_VERSION}-alpine AS hub-builder
WORKDIR /src
COPY go.work go.work.sum ./
COPY cli/go.mod cli/go.sum ./cli/
COPY hub/go.mod hub/go.sum ./hub/
COPY protocol/go.mod ./protocol/
RUN cd hub && go mod download
COPY hub/ ./hub/
COPY protocol/ ./protocol/
RUN cd hub && CGO_ENABLED=0 go build -trimpath -o /out/skillsgo-hub ./cmd/skillsgo-hub

FROM golang:${GO_VERSION}-alpine AS cloud-mock-builder
WORKDIR /src
COPY e2e/cli/go.mod e2e/cli/go.sum ./e2e/cli/
COPY protocol/go.mod protocol/go.sum ./protocol/
COPY protocol/ ./protocol/
COPY e2e/cli/cloud-mock/ ./e2e/cli/cloud-mock/
RUN cd e2e/cli && GOWORK=off CGO_ENABLED=0 go build -trimpath -o /out/skillsgo-cloud-mock ./cloud-mock

FROM alpine:3.23
RUN apk add --no-cache ca-certificates git openssh-client tini
COPY --from=cli-builder /out/skillsgo /usr/local/bin/skillsgo
COPY --from=hub-builder /out/skillsgo-hub /usr/local/bin/skillsgo-hub
COPY --from=cloud-mock-builder /out/skillsgo-cloud-mock /usr/local/bin/skillsgo-cloud-mock
COPY e2e/cli/entrypoint.sh /usr/local/bin/e2e-entrypoint
COPY e2e/cli/git-fixtures.sh /usr/local/bin/e2e-git-fixtures
COPY e2e/cli/git-wrapper.sh /usr/local/bin/git
RUN chmod 0755 /usr/local/bin/skillsgo /usr/local/bin/skillsgo-hub /usr/local/bin/skillsgo-cloud-mock /usr/local/bin/e2e-entrypoint /usr/local/bin/e2e-git-fixtures /usr/local/bin/git
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/e2e-entrypoint"]
