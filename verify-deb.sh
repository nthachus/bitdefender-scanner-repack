#!/bin/sh
. ./verify-func.sh

if dpkg -s apt | grep -i '^Version' | sed 's/^[^0-9]*/1.1\n/' | sort -VC ; then
    INST_CMD='apt-get install -y'
else
    INST_CMD='dpkg -i'
fi
apt-get update -qq

$INST_CMD ./*-repack_*.deb
verify_pkg_installed

verify_scanner_info

verify_scanner_update
pgrep -x bdscan

apt-get purge -y bitdefender-scanner
verify_pkg_removed


$INST_CMD ./*-repack_*.deb
verify_user_added
verify_scanner_update

apt-get remove -y bitdefender-scanner
find / \( -iname '*bitdefender*' -or -iname '*bdscan*' \) -not -path "$PWD/*" -exec ls -lapR {} \;
! verify_user_added

rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*
