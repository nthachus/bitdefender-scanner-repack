#!/bin/sh
set -xe

PKG_NAME=bitdefender-scanner
DEB_FILE="$(dirname "$0")/$PKG_NAME.deb"
OUT_FILE="$DEB_FILE.tgz"

if [ -f "$OUT_FILE" ]; then
    exit 0
fi

if [ ! -f "$DEB_FILE" ]; then
    REPO_URL='http://download.bitdefender.com/repos/deb'
    ARCH=${1:-amd64}

    FILE_NAME="`curl -s "$REPO_URL/dists/bitdefender/non-free/binary-$ARCH/Packages" | grep ":.*/$PKG_NAME/"`"

    curl -Rso "$DEB_FILE" "$REPO_URL/`echo ${FILE_NAME#*:}`"
    dpkg-deb -c "$DEB_FILE" | sort -k6 > "$DEB_FILE.txt"
    rm -rf /tmp/*
fi

PKG_DIR="/tmp/$PKG_NAME"
dpkg-deb -R "$DEB_FILE" "$PKG_DIR/"

BASE_NAME=`ls -1 "$PKG_DIR/opt/" | head -1`
INST_DIR="/opt/$BASE_NAME"
BASE_DIR="$PKG_DIR$INST_DIR"

mv "$PKG_DIR/usr/sbin" "$PKG_DIR/etc"
mv "$BASE_DIR/share/doc/examples/update" "$BASE_DIR/share/contrib/"
chmod +x "$BASE_DIR/share/contrib/update/bdscan-update"

# bash completion plugin
mkdir -p "$PKG_DIR/usr/share/bash-completion/completions"
ln -sf "$INST_DIR/share/contrib/bash_completion/bdscan" "$PKG_DIR/usr/share/bash-completion/completions/"
# cleanup
rm -rf "$PKG_DIR/DEBIAN/preinst" "$BASE_DIR/share/engines" "$BASE_DIR/share/doc/examples"

# configuration file
mv "$BASE_DIR/etc/bdscan.conf.dist" "$BASE_DIR/etc/bdscan.conf"
sed -i ':a;N;$!ba;s/\n\n/\n/g' "$BASE_DIR/etc/bdscan.conf"
sed -i "s,\$\$DIR,$INST_DIR," "$BASE_DIR/etc/bdscan.conf"
echo 'LicenseAccepted = Yes' >> "$BASE_DIR/etc/bdscan.conf"

# library
if grep -q '^Architecture:.*64' "$PKG_DIR/DEBIAN/control"; then
    ARCH=x86_64
else
    ARCH=x86
fi
mv "$BASE_DIR/var/lib/scan/bdcore.so" "$BASE_DIR/var/lib/scan/bdcore.so.linux-$ARCH"
ln -sf "bdcore.so.linux-$ARCH" "$BASE_DIR/var/lib/scan/bdcore.so"

ln -sf "..$INST_DIR/etc" "$PKG_DIR/etc/$BASE_NAME"
# create the symlink to bdscan
ln -sf "$INST_DIR/bin/bdscan" "$PKG_DIR/usr/bin/"

# adjust permissions
chown -Rh root:root "$PKG_DIR/"

# find "$PKG_DIR" -not -type d -exec stat -c '%Y:%n' "{}" \; | sort -nr | head -1 | cut -d: -f2-
NEWEST_FILE="$BASE_DIR/var/bdscan.inf"
find "$PKG_DIR" -newer "$NEWEST_FILE" -exec touch -hr "$NEWEST_FILE" "{}" \;

tar -czf "$OUT_FILE" -C "$PKG_DIR/" .
tar -tzvf "$OUT_FILE" | sort -k6 > "$OUT_FILE.txt"
rm -rf "$PKG_DIR" /tmp/*
