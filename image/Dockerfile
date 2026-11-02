# The reviewer's container image: claude, git and the Go toolchain the
# reviewed repositories build with. It runs as the operator's uid with a
# read-only root, so everything is installed here at build time.
FROM golang:1.26-bookworm AS go

FROM node:22-bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates make \
 && rm -rf /var/lib/apt/lists/*
COPY --from=go /usr/local/go /usr/local/go
ARG CLAUDE_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION} && npm cache clean --force
# Use the image's Go, never download a toolchain: proxy.golang.org is
# allowed for modules only.
ENV PATH=/usr/local/go/bin:$PATH \
    GOTOOLCHAIN=local
