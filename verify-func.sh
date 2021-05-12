#!/bin/sh
set -xe

OWNER=bitdefender
DIR='/opt/BitDefender-scanner'
LOG="$DIR/var/log/bdscan.log"

SC_DIR="$(cd "`dirname "$0"`"; pwd)"
SC_FILE="$SC_DIR/$(basename "$0")"
if echo "${1:-amd64}" | grep -q 64; then BITS=64; else BITS=32; fi

verify_user_added()
{
    grep -i $OWNER /etc/passwd /etc/group
}

verify_scanner_help()
{
    bdscan --help > "$LOG"
    grep '^ *--help' "$LOG"
}

verify_pkg_installed()
{
    list_installed_files
    test -z "`find "$DIR" -not \( -user $OWNER -group $OWNER \)`"

    verify_user_added
    verify_scanner_help
}

verify_scanner_update()
{
    bdscan --update > "$LOG" 2>&1 &
    sleep 3
    grep '\. updated$' "$LOG"
}

list_installed_files()
{
    find / \( -ipath '*bitdefender*' -or -ipath '*bdscan*' \) -not -path "$SC_DIR/*" -exec ls -ldp --full-time "{}" \; \
        | sort -k9 | sed 's/ +0000 /\t/'
}

verify_pkg_removed()
{
    test -z "`list_installed_files`"
    ! verify_user_added
}

verify_scanner_info()
{
    if [ ! -f "$SC_DIR/cumulative$BITS.tgz" ]; then
        return 0
    fi
    tar -xzf "$SC_DIR/cumulative$BITS.tgz" -C "$DIR/var/lib/scan/" --overwrite
    chown -Rh $OWNER:$OWNER "$DIR/var/lib/scan/"

    bdscan --info > "$LOG"
    grep '^Engine signatures: [0-9]' "$LOG"

    bdscan --action=ignore --no-list --log "$SC_FILE"
    grep "$SC_FILE[[:blank:]]\+ok\$" "$LOG"
    grep '^Infected files: 0$' "$LOG"
}
