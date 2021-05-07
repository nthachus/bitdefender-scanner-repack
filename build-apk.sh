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
OUT_FILE="${ZIP_FILE%.*.*}-$PKG_VER.repack.apk"

if [ -f "$OUT_FILE" ]; then
    exit 0
fi

BASE_NAME=`ls -1 "$PKG_DIR/opt/" | head -1`
INST_DIR="/opt/$BASE_NAME"
BASE_DIR="$PKG_DIR$INST_DIR"

#
mkdir -p "$PKG_DIR/etc/periodic/daily"
ln -sf "$INST_DIR/share/contrib/update/bdscan-update" "$PKG_DIR/etc/periodic/daily/"

if grep -q '^Architecture:.*64' "$PKG_DIR/DEBIAN/control"; then
    ARCH=x86_64
else
    ARCH=x86
fi
#ln -sf /lib/libc.musl-$ARCH.so.1 "$BASE_DIR/var/lib/libdl.so.2"

# APK files
mv "$PKG_DIR/DEBIAN" /tmp/
PKG_SIZE=`du -sk "$PKG_DIR" | sed 's/[^0-9].*//'`

echo "pkgname = $PKG_NAME
pkgver = $PKG_VER
$(grep '^Description:' /tmp/DEBIAN/control | sed 's/^Description:/pkgdesc =/')
$(grep '^ \?Homepage:' /tmp/DEBIAN/control | sed 's/^ \?Homepage:/url =/')
arch = $ARCH
origin = ${PKG_NAME%-*}
$(grep '^Maintainer:' /tmp/DEBIAN/control | sed 's/^Maintainer:/maintainer =/')
license = BitDefender
builddate = $(date +%s)
size = $((PKG_SIZE * 1024))
#depend = libc6-compat>1.1.16
depend = libgcc>4.1.1
depend = libstdc++>4.1.1
depend = /bin/sh
# automatically detected:
provides = cmd:bdscan
depend = so:libc.musl-$ARCH.so.1
depend = so:libgcc_s.so.1
depend = so:libstdc++.so.6
#depend = so:libnt.so" > "$PKG_DIR/.PKGINFO"


echo '#!/bin/sh' > "$PKG_DIR/.post-install"
echo "set -x

# library path
#if [ ! -e /etc/ld-musl-$ARCH.path ]; then
#    echo '/lib:/usr/local/lib:/usr/lib' > /etc/ld-musl-$ARCH.path
#fi
#echo '$INST_DIR/var/lib' >> /etc/ld-musl-$ARCH.path

# create the user/group bitdefender, if needed
addgroup -S bitdefender 2>/dev/null || true
adduser -S -h '$INST_DIR' -H -G bitdefender -g BitDefender bitdefender 2>/dev/null || true

# adjust permissions
if ! chown -Rh bitdefender:bitdefender '$INST_DIR' 2>/dev/null ; then
    echo 'Failed to create the necessary user and group' >&2
    exit 1
fi" >> "$PKG_DIR/.post-install"

echo '#!/bin/sh' > "$PKG_DIR/.post-deinstall"
echo "set -x

# library path
#if [ -e /etc/ld-musl-$ARCH.path ]; then
#    sed -i ',$INST_DIR/var/lib,d' /etc/ld-musl-$ARCH.path
#    if [ \"\$(cat /etc/ld-musl-$ARCH.path)\" = '/lib:/usr/local/lib:/usr/lib' ]; then
#        rm -rf /etc/ld-musl-$ARCH.path
#    fi
#fi

# cleanup
rm -rf '$INST_DIR/var' '/usr/share/doc/$PKG_NAME' || true

# remove the bitdefender user and group (if possible)
if [ ! -d /opt/BitDefender* ]; then
    deluser bitdefender 2>/dev/null || true
    delgroup bitdefender 2>/dev/null || true
fi" >> "$PKG_DIR/.post-deinstall"

echo '#!/bin/sh' > "$PKG_DIR/.pre-deinstall"
echo "set -x

# terminate all bdscan instances
pkill -x bdscan 2>/dev/null || true
sleep 2
pkill -x -9 bdscan 2>/dev/null || true" >> "$PKG_DIR/.pre-deinstall"

ln -sf .pre-deinstall "$PKG_DIR/.pre-upgrade"
( cd "$PKG_DIR" && chmod +x .pre-* .post-* )


NEWEST_FILE="$BASE_DIR/var/bdscan.inf"
find "$PKG_DIR" -newer "$NEWEST_FILE" -exec touch -hr "$NEWEST_FILE" "{}" \;

# build package
RSA_FILE="${ZIP_FILE%/*}/abuild-rsa.tgz"
if [ -f "$RSA_FILE" ]; then
    tar -xzf "$RSA_FILE" -C /root/
else
    echo '/root/.abuild/nthachus.github.com-4a6a0840.rsa' | abuild-keygen -a
    tar -czf "$RSA_FILE" -C /root/ .abuild/
fi

( cd "$PKG_DIR" && tar --xattrs -cf- * ) | abuild-tar --hash | gzip -9 > /tmp/data.tar.gz
sha256sum /tmp/data.tar.gz | awk '{print $1}' | sed 's/^/datahash = /' >> "$PKG_DIR/.PKGINFO"
touch -r "$NEWEST_FILE" "$PKG_DIR/.PKGINFO"
( cd "$PKG_DIR" && tar -cf- .???* ) | abuild-tar --cut | gzip -9 > /tmp/control.tar.gz

abuild-sign -q /tmp/control.tar.gz
cat /tmp/control.tar.gz /tmp/data.tar.gz > "$OUT_FILE"
tar -tzvf "$OUT_FILE" | sort -k6 > "$OUT_FILE.txt"
rm -rf "$PKG_DIR" /tmp/*
