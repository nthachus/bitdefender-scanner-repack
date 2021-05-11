#!/bin/sh
SC_DIR="$(dirname "$0")"
. "$SC_DIR/verify-func.sh" "$@"

apt-get update -qq
if echo "${1:-amd64}" | grep -q 64; then ARCH=64; else ARCH=86; fi
( set +x && cd "$SC_DIR" && while [ ! -f ./*-repack_*$ARCH.deb ]; do sleep 1; done )

if dpkg -s apt | grep -i '^Version' | sed 's/^[^0-9]*/1.1\n/' | sort -VC ; then
    INST_CMD='apt-get install -y'
else
    INST_CMD='dpkg -i'
fi
( cd "$SC_DIR" && $INST_CMD ./*-repack_*$ARCH.deb )
verify_pkg_installed

verify_scanner_info

verify_scanner_update
pgrep -x bdscan

apt-get purge -y bitdefender-scanner
verify_pkg_removed


( cd "$SC_DIR" && $INST_CMD ./*-repack_*$ARCH.deb )
verify_user_added
verify_scanner_update

apt-get remove -y bitdefender-scanner
find / \( -iname '*bitdefender*' -or -iname '*bdscan*' \) -not -path "$SC_DIR/*" -exec ls -lapR {} \;
! verify_user_added

rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*
