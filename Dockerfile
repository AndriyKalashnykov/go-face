ARG BUILDER_IMAGE="ghcr.io/andriykalashnykov/dlib-docker:v19.24.4"

FROM ${BUILDER_IMAGE} AS builder

ARG DEBIAN_FRONTEND=noninteractive

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update
RUN apt-get install -y ca-certificates

ARG GO_VER=1.25.3
ARG TARGETOS
ARG TARGETARCH

# https://hub.docker.com/_/golang/
# Install Go
ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache
# Extract Go version from go.mod file instead of hardcoding it
COPY go.mod /tmp/
RUN GO_VER=$(awk '/^go [0-9]+\.[0-9]+/ {print substr($2, 1)}' /tmp/go.mod) && \
    ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?\(v7l\)\?.*/\1\2\3/' -e 's/aarch64$/arm64/' -e 's/armv7l$/armv6l/') && \
    GOFILE="go${GO_VER}.linux-${ARCH}.tar.gz" && \
    curl -sLO "https://go.dev/dl/${GOFILE}" && \
    tar -C /usr/local -xzf "${GOFILE}" && \
    rm -rf "${GOFILE}"

ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/

WORKDIR /app
COPY . .
COPY ./testdata testdata/

RUN /usr/local/go/bin/go mod download
RUN /usr/local/go/bin/go test .

# Keep the container running
CMD ["tail", "-f", "/dev/null"]