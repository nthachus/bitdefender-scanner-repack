#!/bin/sh
set -xe

sed -i 's,/deb\.debian\.org/,/debian.xtdv.net/,' /etc/apt/sources.list
apt-get update -qq
apt-get install -qy --no-install-recommends procps
while [ ! -f ./*.repack.deb ]; do sleep 1; done
apt-get install -y ./*.repack.deb
rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*

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
pgrep -x bdscan
grep '\. updated$' /opt/*/var/log/*.log

apt-get purge -y bitdefender-scanner
[ -z "`find / \( -iname '*bitdefender*' -or -iname '*bdscan*' \) -not -path "$PWD/*"`" ]
! grep -i bitdefender /etc/passwd /etc/group


apt-get install -y ./*.repack.deb
grep -i bitdefender /etc/passwd /etc/group
bdscan --update >> /opt/BitDefender-scanner/var/log/bdscan.log 2>&1 &
sleep 2
grep '\. updated$' /opt/*/var/log/*.log

apt-get remove -y bitdefender-scanner
find / \( -iname '*bitdefender*' -or -iname '*bdscan*' \) -not -path "$PWD/*" -exec ls -lapR {} \;
! grep -i bitdefender /etc/passwd /etc/group

rm -rf /var/cache/apt/* /tmp/*
