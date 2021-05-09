FROM debian:stretch-slim AS debian_verify
ENV LANG C.UTF-8

RUN apt-get update -qq \
 && apt-get install -qy --no-install-recommends procps unzip \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*

FROM debian:stretch-slim@sha256:e6a50e25e7068549e0db47d5553a7d22da8d7df14ad1f298de0f05bb24d8cebd AS i386debian_verify
ENV LANG C.UTF-8

RUN apt-get update -qq \
 && apt-get install -qy --no-install-recommends procps unzip \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*

FROM alpine:3.11 AS alpine_verify
ENV LANG C.UTF-8

RUN apk update -q \
 && apk add -q --no-cache gcompat libgcc libstdc++ \
 && rm -rf /var/cache/apk/* /tmp/*

FROM alpine:3.11@sha256:b2ae6c78091b75954894951fc0b0f6ba2f4997f98b1bb556fe648fb71b5cd370 AS i386alpine_verify
ENV LANG C.UTF-8

RUN apk update -q \
 && apk add -q --no-cache gcompat libgcc libstdc++ \
 && rm -rf /var/cache/apk/* /tmp/*

# Multi-stage builds
FROM alpine_verify AS alpine_repack

RUN apk update \
 && apk add --no-cache dpkg xz abuild \
 && rm -rf /var/cache/apk/* /tmp/*

RUN adduser root abuild \
 && addgroup -S -g 1000 bitdefender \
 && adduser -S -u 1000 -h /opt/BitDefender -H -G bitdefender -g BitDefender bitdefender
