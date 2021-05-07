FROM alpine:3.11

ENV LANG C.UTF-8

RUN apk update \
 && apk add --no-cache dpkg xz abuild \
 && rm -rf /var/cache/apk/* /tmp/*

RUN adduser root abuild
