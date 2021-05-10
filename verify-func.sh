#!/bin/sh
set -xe

UID=bitdefender
DIR='/opt/BitDefender-scanner'
LOG="$DIR/var/log/bdscan.log"

verify_user_added()
{
    grep -i $UID /etc/passwd /etc/group
}

verify_scanner_help()
{
    bdscan --help > "$LOG"
    grep '^ *--help' "$LOG"
}

verify_pkg_installed()
{
    test -z "`find "$DIR" -not \( -user $UID -group $UID \)`"
    verify_user_added

    verify_scanner_help
}

verify_scanner_update()
{
    bdscan --update > "$LOG" 2>&1 &
    sleep 3
    grep '\. updated$' "$LOG"
}

verify_pkg_removed()
{
    test -z "`find / \( -iname '*bitdefender*' -or -iname '*bdscan*' \) -not -path "$PWD/*"`"
    ! verify_user_added
}

verify_scanner_info()
{
    if [ ! -f ./cumulative*.tgz ]; then
        return 0
    fi
    tar -xzf ./cumulative*.tgz -C "$DIR/var/lib/scan/" --overwrite
    chown -Rh $UID:$UID "$DIR/var/lib/scan/"

    bdscan --info > "$LOG"
    grep '^Engine signatures: [0-9]' "$LOG"

    bdscan --action=ignore --no-list --log "$0"
    grep "/$(basename "$0")[[:blank:]]*ok\$" "$LOG"
    grep '^Infected files: 0$' "$LOG"
}
