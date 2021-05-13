FROM debian:stretch-slim AS debian_verify
ENV LANG C.UTF-8

RUN apt-get update -qq \
 && apt-get install -qy --no-install-recommends procps \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/* \
 && sed -i 's,^path-exclude /usr/share/\(doc\|man\)/,#&,' /etc/dpkg/dpkg.cfg.d/*

FROM debian:jessie-slim@sha256:934bdb04f022b992eb1aca12d57ee215d2ffc3275f12250d40c5d094bd480f12 AS i386debian_verify
ENV LANG C.UTF-8

RUN apt-get update -qq \
 && apt-get install -qy --no-install-recommends procps \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/* \
 && sed -i 's,^path-exclude /usr/share/\(doc\|man\)/,#&,' /etc/dpkg/dpkg.cfg.d/*

FROM centos:6 AS centos_verify
ENV LANG en_US.UTF-8

RUN sed 's/^[^0-9]*\| .*$//g' /etc/redhat-release > /etc/yum/vars/releasever \
 && sed -i -e 's/^mirrorlist=/#&/' -e 's/^#\(baseurl=\)/\1/' -e 's,/mirror\(\.centos\.org/\)centos/,/vault\1,' /etc/yum.repos.d/*.repo \
 && sed -i 's/^\(tsflags=.*\)nodocs\(.*\)/\1\2/' /etc/yum.conf

FROM centos:7@sha256:27525fe9e8a84f95baf88459070124628bf83da7216052ea9365fe46e93a102f AS i386centos_verify
ENV LANG en_US.UTF-8

RUN sed -i 's/^\(tsflags=.*\)nodocs\(.*\)/\1\2/' /etc/yum.conf

# 3.8+
FROM alpine:3.10 AS alpine_verify
ENV LANG C.UTF-8

RUN apk update -q \
 && apk add --no-cache gcompat libgcc libstdc++ \
 && rm -rf /var/cache/apk/* /tmp/*

FROM alpine:3.9@sha256:2a41778b4675b9a91bd2ea3a55a2cfdaf4436aa85a476ee8b48993cdd6989a18 AS i386alpine_verify
ENV LANG C.UTF-8

RUN apk update -q \
 && apk add --no-cache gcompat libgcc libstdc++ \
 && rm -rf /var/cache/apk/* /tmp/*

# Multi-stage builds
FROM alpine AS alpine_repack

RUN apk update -q \
 && apk add --no-cache dpkg abuild unzip rpm gnupg \
 && rm -rf /var/cache/apk/* /tmp/*

RUN adduser root abuild \
 && addgroup -S -g 1000 bitdefender \
 && adduser -S -u 1000 -h /opt/BitDefender -H -G bitdefender -g BitDefender bitdefender
