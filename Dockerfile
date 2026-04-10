ARG BUILDER_IMAGE="ghcr.io/andriykalashnykov/dlib-docker:19.24.9@sha256:9cfeadcd58bb474783eec3471b19bcdde1c160b91b06e06df15ef6b5fc4fd95d"

FROM ${BUILDER_IMAGE} AS builder

# dlib-docker's default USER is appuser (uid 1000); switch to root for
# build-time steps (apt, Go install to /usr/local). A later `USER` at
# the bottom of this file drops the final-stage runtime back to nobody.
USER root

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
