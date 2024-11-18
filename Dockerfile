ARG BUILDER_IMAGE="ghcr.io/andriykalashnykov/dlib-docker:v19.24.0"

FROM ${BUILDER_IMAGE} AS builder

#RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM" > /log

ARG GO_VER="1.23.2"
ARG TARGETOS
ARG TARGETARCH

# https://hub.docker.com/_/golang/
# Install Go
RUN curl -sLO https://go.dev/dl/go$GO_VER.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?\(v7l\)\?.*/\1\2\3/' -e 's/aarch64$/arm64/' -e 's/armv7l$/armv6l/').tar.gz \
    && tar -C /usr/local -xzf go$GO_VER.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?\(v7l\)\?.*/\1\2\3/' -e 's/aarch64$/arm64/' -e 's/armv7l$/armv6l/').tar.gz \
    && rm -rf go$GO_VER.linux-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?\(v7l\)\?.*/\1\2\3/' -e 's/aarch64$/arm64/' -e 's/armv7l$/armv6l/').tar.gz

ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/

WORKDIR /app
COPY . .
COPY ./testdata testdata/

RUN /usr/local/go/bin/go mod download
RUN /usr/local/go/bin/go test .

# Keep the container running
CMD ["tail", "-f", "/dev/null"]