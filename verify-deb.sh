#!/bin/sh
set -xe

sed -i 's,/deb\.debian\.org/,/debian.xtdv.net/,' /etc/apt/sources.list
apt-get update -qq
apt-get install -qy --no-install-recommends procps
apt-get install -y ./*.repack.deb
rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*

grep -i bitdefender /etc/passwd /etc/group
bdscan --help >> /opt/BitDefender-scanner/var/log/bdscan.log
bdscan --update >> /opt/BitDefender-scanner/var/log/bdscan.log 2>&1 &
sleep 2
grep '^ *--help' /opt/*/var/log/*.log
grep '\. updated$' /opt/*/var/log/*.log

for action in remove purge; do
    apt-get $action -y bitdefender-scanner
    find / \( -iname '*bitdefender*' -or -iname '*bdscan*' \) -not -path "$PWD/*" -exec ls -lApR {} \;
    ! grep -i bitdefender /etc/passwd /etc/group
done

rm -rf /var/cache/apt/* /tmp/*
