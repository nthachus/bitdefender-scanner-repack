#!/bin/sh
. ./verify-func.sh

apt-get update -qq
apt-get install -y ./*-repack_*.deb
verify_pkg_installed

verify_scanner_info

verify_scanner_update
pgrep -x bdscan

apt-get purge -y bitdefender-scanner
verify_pkg_removed


apt-get install -y ./*-repack_*.deb
verify_user_added
verify_scanner_update

apt-get remove -y bitdefender-scanner
find / \( -iname '*bitdefender*' -or -iname '*bdscan*' \) -not -path "$PWD/*" -exec ls -lapR {} \;
! verify_user_added

rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*
