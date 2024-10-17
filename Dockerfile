#FROM ghcr.io/andriykalashnykov/dlib-docker:v0.0.1 AS dlib-dev


#FROM golang:1.23.2 AS builder

#COPY --from=dlib-dev /usr/local/include/dlib/external/libjpeg/*.h /usr/include/
#COPY --from=dlib-dev /usr/local/include/dlib/ /usr/local/include/dlib/
#COPY --from=dlib-dev /usr/local/lib64/ /usr/local/lib64/

#ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/

#RUN curl -sLO https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && rm -rf go${GO_VERSION}.linux-amd64.tar.gz

# alpine
#FROM imishinist/dlib:19.21 AS dlib-dev
FROM ghcr.io/andriykalashnykov/dlib-docker:v0.0.1 AS dlib-dev
FROM golang:1.23.2-alpine3.20 AS builder
COPY --from=dlib-dev /usr/local/include/dlib/ /usr/local/include/dlib/
#COPY --from=dlib-dev /usr/local/lib64/ /usr/local/lib64/

ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/

ARG TARGETOS TARGETARCH

WORKDIR /app
COPY . .
RUN --mount=target=. \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    CGO_LDFLAGS="-static" GOOS=$TARGETOS GOARCH=$TARGETARCH /usr/local/go/bin/go build -tags static .