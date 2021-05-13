#!/bin/sh
SC_DIR="$(dirname "$0")"
. "$SC_DIR/verify-func.sh" "$@"

apk update -q
if echo "${1:-amd64}" | grep -q 64; then ARCH=64; else ARCH=86; fi
( set +x && cd "$SC_DIR" && while [ ! -f ./*-repack.*$ARCH.apk ]; do sleep 1; done )

( cd "$SC_DIR" && apk add --no-cache --allow-untrusted ./*-repack.*$ARCH.apk )
verify_pkg_installed

verify_scanner_info

verify_scanner_update
pgrep -f '/bin/bdscan'

apk del bitdefender-scanner
verify_pkg_removed
test -d /usr/local/lib

rm -rf /var/cache/apk/* /tmp/*
