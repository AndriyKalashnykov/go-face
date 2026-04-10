ARG BUILDER_IMAGE="ghcr.io/andriykalashnykov/dlib-docker:v20.0.0@sha256:199cece5aca1dc78da78ab22cd075e77b9df4dcd774631830a3bbe5f6f80aa8e"

FROM ${BUILDER_IMAGE} AS builder

ARG DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETOS
ARG TARGETARCH

# Install Go (version extracted from go.mod).
COPY go.mod /tmp/
RUN GO_VER=$(awk '/^go [0-9]+\.[0-9]+/ {print substr($2, 1)}' /tmp/go.mod) && \
    ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?\(v7l\)\?.*/\1\2\3/' -e 's/aarch64$/arm64/' -e 's/armv7l$/armv6l/') && \
    GOFILE="go${GO_VER}.linux-${ARCH}.tar.gz" && \
    curl -sSLO "https://go.dev/dl/${GOFILE}" && \
    tar -C /usr/local -xzf "${GOFILE}" && \
    rm -rf "${GOFILE}"

ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/

WORKDIR /app
COPY --chown=65534:65534 . .

# Drop to a non-root user for runtime (Trivy DS-0002). Users that need
# root (e.g., to apt-get install extra tools) can `docker run -u 0`.
USER 65534:65534

# Keep the container running as a dev/testdata sandbox.
CMD ["tail", "-f", "/dev/null"]
