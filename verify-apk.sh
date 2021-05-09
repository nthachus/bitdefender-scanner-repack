#!/bin/sh
set -xe

apk update -q
apk add -q --no-cache gcompat libgcc libstdc++
while [ ! -f ./*.repack.apk ]; do sleep 1; done
apk add --no-cache --allow-untrusted ./*.repack.apk
rm -rf /var/cache/apk/* /tmp/*

[ -z "`find /opt/* -not \( -user bitdefender -group bitdefender \)`" ]
grep -i bitdefender /etc/passwd /etc/group
bdscan --help >> /opt/BitDefender-scanner/var/log/bdscan.log
grep '^ *--help' /opt/*/var/log/*.log

if [ -f ./threatscanner*.tgz ]; then
    tar -xzf ./threatscanner*.tgz -C /opt/BitDefender-scanner/var/lib/scan/ --overwrite
    chown -Rh bitdefender:bitdefender /opt/*/var/lib/scan/

    bdscan --info >> /opt/BitDefender-scanner/var/log/bdscan.log
    grep '^Engine signatures: [0-9]' /opt/*/var/log/*.log
    bdscan --action=ignore --no-list --log "$0"
    grep "/$(basename "$0")[[:blank:]]*ok\$" /opt/*/var/log/*.log ; grep '^Infected files: 0$' /opt/*/var/log/*.log
fi

bdscan --update >> /opt/BitDefender-scanner/var/log/bdscan.log 2>&1 &
sleep 2
pgrep -f '/bin/bdscan'
grep '\. updated$' /opt/*/var/log/*.log

apk del bitdefender-scanner
[ -z "`find / \( -iname '*bitdefender*' -or -iname '*bdscan*' \) -not -path "$PWD/*"`" ]
! grep -i bitdefender /etc/passwd /etc/group

rm -rf /var/cache/apk/* /tmp/*
