# [INPUT]: Depends on the repository Go workspace, Protocol and Hub modules, Alpine runtime packages, and the target build architecture.
# [OUTPUT]: Produces the multi-architecture SkillsGo Hub container image and runtime command.
# [POS]: Serves as the production container build for the Hub service and GHCR publication workflow.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
# Links to compare against to ensure we have all VCS's setup in this build
# https://github.com/docker-library/buildpack-deps/blob/1845b3f918f69b4c97912b0d4d68a5658458e84f/stretch/scm/Dockerfile
# https://github.com/golang/go/blob/f082dbfd4f23b0c95ee1de5c2b091dad2ff6d930/src/cmd/go/internal/get/vcs.go#L90
#
# You can override the Go version used to build the image.
# See project Makefile if using make.
# See docker --build-arg if building directly.
ARG GOLANG_VERSION=1.26.4

FROM golang:${GOLANG_VERSION}-alpine AS builder

ARG VERSION="unset"
ARG TARGETARCH

ENV GOARCH=${TARGETARCH} \
    GO111MODULE=on \
    CGO_ENABLED=0 \
    GOPROXY="https://proxy.golang.org"

WORKDIR /src

COPY go.work go.work.sum ./
COPY cli/go.mod cli/go.sum ./cli/
COPY hub/go.mod hub/go.sum ./hub/
COPY protocol/go.mod ./protocol/
RUN cd hub && go mod download
COPY hub/ ./hub/
COPY protocol/ ./protocol/

RUN DATE="$(date -u +%Y-%m-%d-%H:%M:%S-%Z)" && \
    cd hub && go build \
    -ldflags "-X github.com/skillsgo/skillsgo/hub/pkg/build.version=$VERSION -X github.com/skillsgo/skillsgo/hub/pkg/build.buildDate=$DATE -s -w" \
    -o /bin/skillsgo-hub ./cmd/skillsgo-hub

FROM alpine:3.23
ARG TARGETARCH

ENV GOROOT="/usr/local/go" \
    PATH=/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    GO111MODULE=on

COPY --from=builder /bin/skillsgo-hub /bin/skillsgo-hub
COPY --from=builder /src/hub/config.dev.toml /config/config.toml
COPY --from=builder /usr/local/go/bin/go /usr/local/go/bin/go
COPY --from=builder /usr/local/go/go.env /usr/local/go/go.env

RUN chmod 644 /config/config.toml

# Add tini, see https://github.com/gomods/athens/issues/1155 for details.
RUN apk add --update git git-lfs mercurial openssh-client subversion procps fossil tini tzdata

# Add git-credential-github-app for native integration with GitHub Apps
RUN if [ "${TARGETARCH}" = "arm64" ]; then ARCH="arm64"; else ARCH="x86_64"; fi \
  && wget -O git-credential-github-app.tar.gz https://github.com/bdellegrazie/git-credential-github-app/releases/download/v0.3.4/git-credential-github-app_v0.3.4_Linux_${ARCH}.tar.gz \
  && tar xvzf 'git-credential-github-app.tar.gz' git-credential-github-app -C /usr/local/bin \
  && rm git-credential-github-app.tar.gz || true;

ARG USER=athens
RUN adduser -D -h /home/$USER $USER

EXPOSE 3000

ENTRYPOINT [ "/sbin/tini", "--" ]

CMD ["skillsgo-hub", "-config_file=/config/config.toml"]
