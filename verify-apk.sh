#!/bin/sh
set -xe

apk update -q
apk add -q --no-cache libgcc libstdc++
apk add --no-cache --allow-untrusted ./*.repack.apk
rm -rf /var/cache/apk/* /tmp/*

if [ ! -e /lib64/ld-linux-x86-64.so.2 ]; then
    mkdir -p /lib64
    ln -s /lib/ld-musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2
fi

grep -i bitdefender /etc/passwd /etc/group
bdscan --help >> /opt/BitDefender-scanner/var/log/bdscan.log
bdscan --update >> /opt/BitDefender-scanner/var/log/bdscan.log 2>&1 &
sleep 2
grep '^ *--help' /opt/*/var/log/*.log
grep '\. updated$' /opt/*/var/log/*.log

apk del bitdefender-scanner
find / \( -iname '*bitdefender*' -or -iname '*bdscan*' \) -not -path "$PWD/*" -exec ls -lApR {} \;
! grep -i bitdefender /etc/passwd /etc/group

rm -rf /var/cache/apk/* /tmp/*
