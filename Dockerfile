FROM debian:stretch-slim AS debian_verify
ENV LANG C.UTF-8

RUN apt-get update -qq \
 && apt-get install -qy --no-install-recommends procps \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*

FROM debian:jessie-slim@sha256:934bdb04f022b992eb1aca12d57ee215d2ffc3275f12250d40c5d094bd480f12 AS i386debian_verify
ENV LANG C.UTF-8

RUN apt-get update -qq \
 && apt-get install -qy --no-install-recommends procps \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*

# 3.8+
FROM alpine:3.11 AS alpine_verify
ENV LANG C.UTF-8

RUN apk update -q \
 && apk add -q --no-cache gcompat libgcc libstdc++ \
 && rm -rf /var/cache/apk/* /tmp/*

FROM alpine:3.9@sha256:2a41778b4675b9a91bd2ea3a55a2cfdaf4436aa85a476ee8b48993cdd6989a18 AS i386alpine_verify
ENV LANG C.UTF-8

RUN apk update -q \
 && apk add -q --no-cache gcompat libgcc libstdc++ \
 && rm -rf /var/cache/apk/* /tmp/*

# Multi-stage builds
FROM alpine:3.11 AS alpine_repack

RUN apk update \
 && apk add --no-cache dpkg xz abuild unzip \
 && rm -rf /var/cache/apk/* /tmp/*

RUN adduser root abuild \
 && addgroup -S -g 1000 bitdefender \
 && adduser -S -u 1000 -h /opt/BitDefender -H -G bitdefender -g BitDefender bitdefender
