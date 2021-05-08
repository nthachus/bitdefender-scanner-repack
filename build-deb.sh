#!/bin/sh
set -xe

PKG_NAME=bitdefender-scanner
ZIP_FILE="$(dirname "$0")/$PKG_NAME.deb.tgz"

if [ ! -f "$ZIP_FILE" ]; then
    exit 1
fi

PKG_DIR="/tmp/$PKG_NAME"
mkdir "$PKG_DIR"
tar -xzf "$ZIP_FILE" -C "$PKG_DIR/"

PKG_VER=`grep '^Version:' "$PKG_DIR/DEBIAN/control" | sed 's/^Version:[ \t]*//'`
ARCH=`grep '^Architecture:' "$PKG_DIR/DEBIAN/control" | sed 's/^Architecture:[ \t]*//'`
OUT_FILE="${ZIP_FILE%.*.*}_${PKG_VER}_$ARCH.repack.deb"

if [ -f "$OUT_FILE" ]; then
    rm -rf "$PKG_DIR"
    exit 0
fi

BASE_NAME=`ls -1 "$PKG_DIR/opt/" | head -1`
INST_DIR="/opt/$BASE_NAME"
BASE_DIR="$PKG_DIR$INST_DIR"

# library path
mkdir -p "$PKG_DIR/etc/ld.so.conf.d" "$PKG_DIR/etc/cron.daily"
echo "$INST_DIR/var/lib" > "$PKG_DIR/etc/ld.so.conf.d/bdscan.conf"

ln -sf "$INST_DIR/share/contrib/update/bdscan-update" "$PKG_DIR/etc/cron.daily/"

# DEBIAN files
echo 'activate-noawait ldconfig' > "$PKG_DIR/DEBIAN/triggers"

mv "$PKG_DIR/DEBIAN" /tmp/
PKG_SIZE=`du -sk "$PKG_DIR" | sed 's/[^0-9].*//'`
mv /tmp/DEBIAN "$PKG_DIR/"
sed -i -e 's/^Depends:.*/&\nRecommends: libc-bin, procps/' -e "s/^\(Installed-Size:\).*/\1 $PKG_SIZE/" "$PKG_DIR/DEBIAN/control"

echo "/etc/$BASE_NAME/bdscan.conf
$INST_DIR/etc/bdscan.conf" > "$PKG_DIR/DEBIAN/conffiles"

find "$PKG_DIR" -not -type d -not -path '*/etc/bdscan.conf' -not -path '*/DEBIAN/*' -exec md5sum "{}" + \
    | sed "s,^\(.*\)$INST_DIR\(/bin/.*\|/share/man/.*\),&\n\1/usr\2," \
    | sed "s,^\(.*\)$INST_DIR/share/contrib/bash_completion\(/bd.*\),&\n\1/usr/share/bash-completion/completions\2," \
    | sed "s,^\(.*\)$INST_DIR/share/contrib/update\(/.*\),&\n\1/etc/cron.daily\2," \
    | sed "s, \+\*\?$PKG_DIR/,  ," | sort -k2 > "$PKG_DIR/DEBIAN/md5sums"


echo '#!/bin/sh' > "$PKG_DIR/DEBIAN/postinst"
echo "set -e
DIR='$INST_DIR'

case \$1 in
configure)
    BD_SHELL=noshell
    if [ -x /bin/false ]; then
        BD_SHELL=/bin/false
    elif [ -x /sbin/nologin ]; then
        BD_SHELL=/sbin/nologin
    elif [ -x /usr/sbin/nologin ]; then
        BD_SHELL=/usr/sbin/nologin
    fi

    # create the user/group bitdefender, if needed
    groupadd --system bitdefender 2>/dev/null || true
    useradd --system -d \"\$DIR\" --no-create-home --shell \$BD_SHELL -g bitdefender -c BitDefender bitdefender 2>/dev/null || true

    # adjust permissions
    if ! chown -Rh bitdefender:bitdefender \"\$DIR\" 2>/dev/null ; then
        echo 'Failed to create the necessary user and group' >&2
        exit 1
    fi
;;
esac" >> "$PKG_DIR/DEBIAN/postinst"

echo '#!/bin/sh' > "$PKG_DIR/DEBIAN/postrm"
echo "set -e
DIR='$INST_DIR'

case \$1 in
purge|remove)
    # cleanup
    rm -rf \"\$DIR/var\" '/usr/share/doc/$PKG_NAME' || true
    rmdir --ignore-fail-on-non-empty \"\$DIR\" 2>/dev/null || true

    # remove the bitdefender user and group (if possible)
    if [ -z \"\$(ls -1dp /opt/BitDefender* 2>/dev/null | grep -v \"\$DIR/\")\" ]; then
        userdel bitdefender 2>/dev/null || true
        groupdel bitdefender 2>/dev/null || true
    fi
;;
upgrade)
    # remove our path from manpath since this is deprecated
    # this is done for compatibility reasons with older packages
    for f in man manpath; do
        if [ -f /etc/\$f.config ]; then
            sed -i \",\$DIR/share/man,d\" /etc/\$f.config
        fi
    done
;;
esac" >> "$PKG_DIR/DEBIAN/postrm"

echo '#!/bin/sh' > "$PKG_DIR/DEBIAN/prerm"
echo "set -e

case \$1 in
remove|upgrade)
    # terminate all bdscan instances
    pkill -x bdscan 2>/dev/null || true
    sleep 2
    pkill -x -9 bdscan 2>/dev/null || true
;;
esac" >> "$PKG_DIR/DEBIAN/prerm"


NEWEST_FILE="$BASE_DIR/var/bdscan.inf"
find "$PKG_DIR" -newer "$NEWEST_FILE" -exec touch -hr "$NEWEST_FILE" "{}" \;

dpkg-deb -b "$PKG_DIR" "$OUT_FILE"
dpkg-deb -c "$OUT_FILE" | sort -k6 > "$OUT_FILE.txt"
rm -rf "$PKG_DIR" /tmp/*
