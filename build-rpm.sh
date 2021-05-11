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
    ARCH=i586
fi
PKG_VER=`grep '^Version:' "$PKG_DIR/DEBIAN/control" | sed 's/^Version:[ \t]*//'`
OUT_FILE="${ZIP_FILE%_*}-${PKG_VER}_repack.$ARCH.rpm"

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

# library path
mkdir -p "$PKG_DIR/etc/ld.so.conf.d" "$PKG_DIR/etc/cron.daily"
echo "$INST_DIR/var/lib" > "$PKG_DIR/etc/ld.so.conf.d/bdscan.conf"

ln -sf "$INST_DIR/share/contrib/update/bdscan-update" "$PKG_DIR/etc/cron.daily/"


# SPECS
mv "$PKG_DIR/DEBIAN" /tmp/
if [ $ARCH = x86_64 ]; then BITS='(64bit)'; else BITS=''; fi

echo "Name: $PKG_NAME
Version: ${PKG_VER%-*}
Release: ${PKG_VER#*-}_repack
$(grep '^Description:' /tmp/DEBIAN/control | sed 's/^Description/Summary/')
License: SC. BitDefender SRL.
$(grep '^ \?Homepage:' /tmp/DEBIAN/control | sed 's/^ \?Homepage/URL/')
$(grep '^Maintainer:' /tmp/DEBIAN/control | sed 's/^Maintainer/Packager/')
Group: Applications/System
#Requires: glibc > 2.3.6, libgcc > 4.1.1, libstdc++ > 4.1.1
Requires: /sbin/ldconfig
Provides: bdscan = ${PKG_VER}
Requires: libc.so.6()$BITS, libc.so.6(GLIBC_2.2.5)$BITS, libc.so.6(GLIBC_2.3.4)$BITS, libc.so.6(GLIBC_2.3)$BITS
Requires: libdl.so.2()$BITS, libdl.so.2(GLIBC_2.2.5)$BITS, libm.so.6()$BITS, libm.so.6(GLIBC_2.2.5)$BITS, libpthread.so.0()$BITS, libpthread.so.0(GLIBC_2.2.5)$BITS
Requires: libgcc_s.so.1()$BITS, libgcc_s.so.1(GCC_3.0)$BITS
Requires: libstdc++.so.6()$BITS, libstdc++.so.6(GLIBCXX_3.4)$BITS, libstdc++.so.6(CXXABI_1.3)$BITS

%description
$(grep '^\( \|Description:\)' /tmp/DEBIAN/control | sed -e 's/^\(Description:\)\? *//' -e 's/^\.$//' -e '/^Homepage/d')

%files
/*

%changelog
$(gunzip -c "$PKG_DIR/usr/share/doc/$PKG_NAME/changelog.gz" \
    | sed -e '/^$/d' -e 's/^[^ ].*(\(.*\)).*/\1/' -e 's/^ *\*/-/' \
    | tr '\n' '\f' | sed -e 's/\f$/\n/' -e 's/\f\([^ -]\)/\n\n\1/' \
    | sed 's/^\([^\f]*\)\f\(.*\)\f --\(.*>\) \+\([^ ]*\), \([0-9]*\) \([^ ]*\) \([0-9]*\).*/* \4 \6 \5 \7 \3 - \1\n\2/' \
    | tr '\f' '\n')

%filetriggerin -P 2000000 -- /etc/ld.so.conf.d
/sbin/ldconfig

%filetriggerun -P 2000000 -- /etc/ld.so.conf.d
/sbin/ldconfig

%post
set -e
DIR='$INST_DIR'

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

%preun
set -e

# terminate all bdscan instances
pkill -x bdscan 2>/dev/null || true
sleep 2
pkill -x -9 bdscan 2>/dev/null || true

%postun
set -e
DIR='$INST_DIR'

# upgrade?
if [ \"\$1\" = '1' ]; then
    # remove our path from manpath since this is deprecated
    # this is done for compatibility reasons with older packages
    for f in man manpath; do
        if [ -f /etc/\$f.config ]; then
            sed -i \",\$DIR/share/man,d\" /etc/\$f.config
        fi
    done
else
    # cleanup
    rm -rf \"\$DIR/var\" '/usr/share/doc/$PKG_NAME' || true
    rmdir --ignore-fail-on-non-empty \"\$DIR\" 2>/dev/null || true

    # remove the bitdefender user and group (if possible)
    if [ -z \"\$(ls -1dp /opt/BitDefender* 2>/dev/null | grep -v \"\$DIR/\")\" ]; then
        userdel bitdefender 2>/dev/null || true
        groupdel bitdefender 2>/dev/null || true
    fi
fi
" > "/tmp/$PKG_NAME.spec"


NEWEST_FILE="$BASE_DIR/var/bdscan.inf"
find "$PKG_DIR" -newer "$NEWEST_FILE" -exec touch -hr "$NEWEST_FILE" "{}" \;

# sign ???
rpmbuild -bb --buildroot "$PKG_DIR" --nodeps --target "$ARCH-pc-linux" -D "%_target_platform $ARCH-pc-linux" "/tmp/$PKG_NAME.spec"
mv ~/rpmbuild/RPMS/*/*.rpm "${OUT_FILE%/*}/"
rpm -qpi --provides -R --changelog --filetriggers --scripts -lv "$OUT_FILE" > "$OUT_FILE.txt"

rm -rf "$PKG_DIR" ~/rpmbuild /tmp/*
