# [INPUT]: Depends on the repository Go workspace, Protocol and Hub modules, and a network-capable Linux container runtime.
# [OUTPUT]: Produces a minimal disposable image containing only the real SkillsGo Hub and its Git transport dependencies.
# [POS]: Serves as the clean Hub boundary for macOS App E2E journeys; the CLI remains bundled inside the App.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ARG GO_VERSION=1.26.5

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

FROM alpine:3.23
RUN apk add --no-cache ca-certificates git openssh-client tini
COPY --from=hub-builder /out/skillsgo-hub /usr/local/bin/skillsgo-hub
RUN chmod 0755 /usr/local/bin/skillsgo-hub
EXPOSE 3000
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/skillsgo-hub"]
