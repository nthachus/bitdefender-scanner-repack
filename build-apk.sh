#!/bin/sh
set -xe

PKG_NAME=bitdefender-scanner
ARCH=${1:-amd64}
ZIP_FILE="$(dirname "$0")/${PKG_NAME}_$ARCH.deb.tgz"

if [ ! -f "$ZIP_FILE" ]; then
    exit 1
fi

PKG_DIR="/tmp/$PKG_NAME"
mkdir "$PKG_DIR"
tar -xzf "$ZIP_FILE" -C "$PKG_DIR/"

if grep -q '^Architecture:.*64' "$PKG_DIR/DEBIAN/control"; then
    ARCH=x86_64
else
    ARCH=x86
fi
PKG_VER=`grep '^Version:' "$PKG_DIR/DEBIAN/control" | sed 's/^Version:[ \t]*//'`
OUT_FILE="${ZIP_FILE%_*}-${PKG_VER}-repack.$ARCH.apk"

if [ -f "$OUT_FILE" ]; then
    rm -rf "$PKG_DIR"
    exit 0
fi

BASE_NAME=`ls -1 "$PKG_DIR/opt/" | head -1`
INST_DIR="/opt/$BASE_NAME"
BASE_DIR="$PKG_DIR$INST_DIR"

#
( cd "$PKG_DIR/usr/share/doc/$PKG_NAME" \
    && mv changelog*.gz changelog.gz && rm -rf *.Debian* && sed -i '/^Copyright:/!d' copyright )

mkdir -p "$PKG_DIR/etc/periodic/daily" "$PKG_DIR/usr/local/lib"
ln -sf "$INST_DIR/share/contrib/update/bdscan-update" "$PKG_DIR/etc/periodic/daily/"
ln -sf "$INST_DIR/var/lib/scan" "$PKG_DIR/usr/local/lib/bdscan"

# APK files
mv "$PKG_DIR/DEBIAN" /tmp/
PKG_SIZE=`du -sk "$PKG_DIR" | sed 's/[^0-9].*//'`

echo "pkgname = $PKG_NAME
pkgver = ${PKG_VER}-repack
$(grep '^Description:' /tmp/DEBIAN/control | sed 's/^Description:/pkgdesc =/')
$(grep '^ \?Homepage:' /tmp/DEBIAN/control | sed 's/^ \?Homepage:/url =/')
arch = $ARCH
origin = ${PKG_NAME%-*}
$(grep '^Maintainer:' /tmp/DEBIAN/control | sed 's/^Maintainer:/maintainer =/')
license = SC. BitDefender SRL.
builddate = $(date +%s)
size = $((PKG_SIZE * 1024))
depend = gcompat>0.2.0
depend = libgcc>4.1.1
depend = libstdc++>4.1.1
depend = /bin/sh
# automatically detected:
provides = cmd:bdscan
depend = so:libc.musl-$ARCH.so.1
depend = so:libgcc_s.so.1
depend = so:libstdc++.so.6
#depend = so:libnt.so" > "$PKG_DIR/.PKGINFO"


echo '#!/bin/sh' > "$PKG_DIR/.pre-install"
echo "set -e
DIR='$INST_DIR'

# create the user/group bitdefender, if needed
addgroup -S bitdefender 2>/dev/null || true
adduser -S -h \"\$DIR\" -H -G bitdefender -g BitDefender bitdefender 2>/dev/null || true

# library compatibility" >> "$PKG_DIR/.pre-install"

if [ $ARCH = x86_64 ]; then
    echo "if [ ! -e /lib64/ld-linux-x86-64.so.2 ]; then
    mkdir -p /lib64
    ln -sf /lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
fi" >> "$PKG_DIR/.pre-install"
else
    echo "if [ ! -e /lib/ld-musl-x86.so.1 ]; then
    ln -sf ld-musl-i386.so.1 /lib/ld-musl-x86.so.1
fi" >> "$PKG_DIR/.pre-install"
fi

echo '#!/bin/sh' > "$PKG_DIR/.post-deinstall"
echo "set -e
DIR='$INST_DIR'

# cleanup
rm -rf \"\$DIR/var\" '/usr/share/doc/$PKG_NAME' || true
rmdir --ignore-fail-on-non-empty \"\$DIR\" 2>/dev/null || true

# remove the bitdefender user and group (if possible)
if [ -z \"\$(ls -1dp /opt/BitDefender* 2>/dev/null | grep -v \"\$DIR/\")\" ]; then
    deluser bitdefender 2>/dev/null || true
    delgroup bitdefender 2>/dev/null || true
fi" >> "$PKG_DIR/.post-deinstall"

echo '#!/bin/sh' > "$PKG_DIR/.pre-deinstall"
echo "set -e

# terminate all bdscan instances
pkill -f '/bin/bdscan' 2>/dev/null || true
sleep 2
pkill -f -9 '/bin/bdscan' 2>/dev/null || true" >> "$PKG_DIR/.pre-deinstall"

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
