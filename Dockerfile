#FROM ghcr.io/andriykalashnykov/dlib-docker:v0.0.1 AS dlib-dev


#FROM golang:1.23.2 AS builder

#COPY --from=dlib-dev /usr/local/include/dlib/external/libjpeg/*.h /usr/include/
#COPY --from=dlib-dev /usr/local/include/dlib/ /usr/local/include/dlib/
#COPY --from=dlib-dev /usr/local/lib64/ /usr/local/lib64/

#ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/

#RUN curl -sLO https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && rm -rf go${GO_VERSION}.linux-amd64.tar.gz

# alpine
#FROM imishinist/dlib:19.21 AS dlib-dev
#FROM golang:1.23.2-alpine3.20 AS builder
#COPY --from=dlib-dev /usr/local/include/dlib/ /usr/local/include/dlib/
#COPY --from=dlib-dev /usr/local/lib64/ /usr/local/lib64/

# debian
FROM ghcr.io/andriykalashnykov/dlib-docker:v0.0.1 AS dlib-dev
# https://hub.docker.com/_/golang/

# Install Go
RUN curl -sLO https://go.dev/dl/go1.23.2.linux-amd64.tar.gz && tar -C /usr/local -xzf go1.23.2.linux-amd64.tar.gz && rm -rf go1.23.2.linux-amd64.tar.gz

ENV PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/

WORKDIR /app
COPY . .
COPY ./testdata testdata/

RUN /usr/local/go/bin/go mod download
RUN /usr/local/go/bin/go test .

# Keep the container running
CMD ["tail", "-f", "/dev/null"]