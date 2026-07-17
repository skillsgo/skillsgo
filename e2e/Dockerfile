# [INPUT]: Depends on the CLI and Hub Go workspaces plus the e2e container entrypoint.
# [OUTPUT]: Produces one reusable Linux image containing both real product binaries and runtime VCS tools.
# [POS]: Serves as the disposable single-container runtime for every cross-product e2e scenario.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
ARG GO_VERSION=1.26.5

FROM golang:${GO_VERSION}-alpine AS cli-builder
WORKDIR /src/cli
COPY cli/go.mod cli/go.sum ./
RUN go mod download
COPY cli/ ./
RUN CGO_ENABLED=0 go build -trimpath -o /out/skillsgo ./cmd/skillsgo

FROM golang:${GO_VERSION}-alpine AS hub-builder
WORKDIR /src/hub
COPY hub/go.mod hub/go.sum ./
RUN go mod download
COPY hub/ ./
RUN CGO_ENABLED=0 go build -trimpath -o /out/skillsgo-hub ./cmd/skillsgo-hub

FROM alpine:3.23
RUN apk add --no-cache ca-certificates git openssh-client tini
COPY --from=cli-builder /out/skillsgo /usr/local/bin/skillsgo
COPY --from=hub-builder /out/skillsgo-hub /usr/local/bin/skillsgo-hub
COPY e2e/entrypoint.sh /usr/local/bin/e2e-entrypoint
RUN chmod 0755 /usr/local/bin/skillsgo /usr/local/bin/skillsgo-hub /usr/local/bin/e2e-entrypoint
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/e2e-entrypoint"]
