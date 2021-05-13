#!/bin/sh
SC_DIR="$(dirname "$0")"
. "$SC_DIR/verify-func.sh" "$@"

yum -x '*' -q update
if echo "${1:-amd64}" | grep -q 64; then ARCH=64; else ARCH=86; fi
( set +x && cd "$SC_DIR" && while [ ! -f ./*_repack.*$ARCH.rpm ]; do sleep 1; done )

( cd "$SC_DIR" && yum install -y --nogpgcheck --setopt 'tsflags=' ./*_repack.*$ARCH.rpm )
verify_pkg_installed

verify_scanner_info

verify_scanner_update
pgrep -x bdscan

yum erase -y --setopt 'tsflags=' bitdefender-scanner
verify_pkg_removed

rm -rf /var/cache/yum/* /tmp/*
