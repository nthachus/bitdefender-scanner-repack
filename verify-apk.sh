#!/bin/sh
. ./verify-func.sh

apk add --no-cache --allow-untrusted ./*-repack.*.apk
verify_pkg_installed

verify_scanner_info

verify_scanner_update
pgrep -f '/bin/bdscan'

apk del bitdefender-scanner
verify_pkg_removed

rm -rf /var/cache/apk/* /tmp/*
