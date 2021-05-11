#!/bin/sh
set -xe

UID=bitdefender
DIR='/opt/BitDefender-scanner'
LOG="$DIR/var/log/bdscan.log"

SC_FILE="$(realpath "$0")"
SC_DIR="$(dirname "$SC_FILE")"
if echo "${1:-amd64}" | grep -q 64; then BITS=64; else BITS=32; fi

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
    test -z "`find / \( -iname '*bitdefender*' -or -iname '*bdscan*' \) -not -path "$SC_DIR/*"`"
    ! verify_user_added
}

verify_scanner_info()
{
    if [ ! -f "$SC_DIR/cumulative$BITS.tgz" ]; then
        return 0
    fi
    tar -xzf "$SC_DIR/cumulative$BITS.tgz" -C "$DIR/var/lib/scan/" --overwrite
    chown -Rh $UID:$UID "$DIR/var/lib/scan/"

    bdscan --info > "$LOG"
    grep '^Engine signatures: [0-9]' "$LOG"

    bdscan --action=ignore --no-list --log "$SC_FILE"
    grep "$SC_FILE[[:blank:]]*ok\$" "$LOG"
    grep '^Infected files: 0$' "$LOG"
}
