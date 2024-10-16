ARG CROSS="true"
ARG GO_VERSION=1.23.2
ARG UBUNTU_VERSION=24.04
ARG DEBIAN_FRONTEND=noninteractive
ARG BASE_DEBIAN_DISTRO="bullseye"
ARG GOLANG_IMAGE="golang:${GO_VERSION}-${BASE_DEBIAN_DISTRO}"
#ARG GOLANG_IMAGE="ubuntu:${UBUNTU_VERSION}"


FROM ${GOLANG_IMAGE} AS base
RUN echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
ARG APT_MIRROR
RUN sed -ri "s/(httpredir|deb).debian.org/${APT_MIRROR:-deb.debian.org}/g" /etc/apt/sources.list \
 && sed -ri "s/(security).debian.org/${APT_MIRROR:-security.debian.org}/g" /etc/apt/sources.list
ENV GO111MODULE=off

#FROM base AS cross-false

FROM base AS cross-true
ARG DEBIAN_FRONTEND
RUN dpkg --add-architecture arm64
RUN dpkg --add-architecture armel
RUN dpkg --add-architecture armhf
RUN --mount=type=cache,sharing=locked,id=moby-cross-true-aptlib,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,id=moby-cross-true-aptcache,target=/var/cache/apt \
        apt-get update && apt-get install -y --no-install-recommends \
            crossbuild-essential-arm64 \
            crossbuild-essential-armel \
            crossbuild-essential-armhf

#FROM cross-${CROSS} AS dev-base
#
#FROM dev-base AS runtime-dev-cross-false
#ARG DEBIAN_FRONTEND
#RUN --mount=type=cache,sharing=locked,id=moby-cross-false-aptlib,target=/var/lib/apt \
#    --mount=type=cache,sharing=locked,id=moby-cross-false-aptcache,target=/var/cache/apt \
#        apt-get update && apt-get install -y --no-install-recommends \
#            binutils-mingw-w64 \
#            g++-mingw-w64-x86-64 \
#            libapparmor-dev \
#            libbtrfs-dev \
#            libdevmapper-dev \
#            libseccomp-dev \
#            libsystemd-dev \
#            libudev-dev

FROM cross-true AS runtime-dev-cross-true
ARG DEBIAN_FRONTEND
# These crossbuild packages rely on gcc-<arch>, but this doesn't want to install
# on non-amd64 systems, so other architectures cannot crossbuild amd64.
RUN --mount=type=cache,sharing=locked,id=moby-cross-true-aptlib,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,id=moby-cross-true-aptcache,target=/var/cache/apt \
        apt-get update && apt-get install -y --no-install-recommends \
            libapparmor-dev:arm64 \
            libapparmor-dev:armel \
            libapparmor-dev:armhf \
            libseccomp-dev:arm64 \
            libseccomp-dev:armel \
            libseccomp-dev:armhf

FROM runtime-dev-cross-${CROSS} AS runtime-dev

RUN apt-get update
RUN apt-get install -y build-essential cmake curl
RUN mkdir /dlib && cd /dlib && curl -sLO http://dlib.net/files/dlib-19.24.tar.bz2 && tar xf dlib-19.24.tar.bz2
# -DDLIB_PNG_SUPPORT=ON -DDLIB_GIF_SUPPORT=ON -DDLIB_JPEG_SUPPORT=ON -DDLIB_NO_GUI_SUPPORT=ON
# https://github.com/imishinist/dlib/blob/master/19.21/buster/Dockerfile
RUN cd /dlib/dlib-19.24 && mkdir build && cd build && cmake .. && cmake --build . --config Release && make install && rm -rf /dlib \
    rm dlib-19.24.tar.bz2 dlib-19.24.tar.gz dlib-19.24.tar
