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
PKG_OWNER="`grep '^Maintainer:' /tmp/DEBIAN/control | sed 's/^Maintainer: *//'`"

echo "Name: $PKG_NAME
Version: ${PKG_VER%-*}
Release: ${PKG_VER#*-}_repack
$(grep '^Description:' /tmp/DEBIAN/control | sed 's/^Description/Summary/')
License: SC. BitDefender SRL.
$(grep '^ \?Homepage:' /tmp/DEBIAN/control | sed 's/^ \?Homepage/URL/')
Packager: $PKG_OWNER
Group: Applications/System
#Requires: glibc > 2.3.6, libgcc > 4.1.1, libstdc++ > 4.1.1
Requires: /sbin/ldconfig
Provides: /usr/bin/bdscan" > "/tmp/$PKG_NAME.spec"

if [ $ARCH = x86_64 ]; then
    echo "Provides: bdupd.so()(64bit), bdcore.so()(64bit)
Requires: libc.so.6()(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit)
Requires: libdl.so.2()(64bit), libdl.so.2(GLIBC_2.2.5)(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libpthread.so.0()(64bit), libpthread.so.0(GLIBC_2.2.5)(64bit)
Requires: libgcc_s.so.1()(64bit), libgcc_s.so.1(GCC_3.0)(64bit)
Requires: libstdc++.so.6()(64bit), libstdc++.so.6(GLIBCXX_3.4)(64bit), libstdc++.so.6(CXXABI_1.3)(64bit)" >> "/tmp/$PKG_NAME.spec"
else
    echo "Provides: bdupd.so, bdcore.so
Requires: libc.so.6, libc.so.6(GLIBC_2.0), libc.so.6(GLIBC_2.1), libc.so.6(GLIBC_2.1.2), libc.so.6(GLIBC_2.2), libc.so.6(GLIBC_2.2.3), libc.so.6(GLIBC_2.3), libc.so.6(GLIBC_2.3.4)
Requires: libdl.so.2, libdl.so.2(GLIBC_2.0), libdl.so.2(GLIBC_2.1), libm.so.6, libm.so.6(GLIBC_2.1)
Requires: libpthread.so.0, libpthread.so.0(GLIBC_2.0), libpthread.so.0(GLIBC_2.1), libpthread.so.0(GLIBC_2.2)
Requires: libgcc_s.so.1, libgcc_s.so.1(GCC_3.0), libstdc++.so.6, libstdc++.so.6(GLIBCXX_3.4), libstdc++.so.6(CXXABI_1.3)" >> "/tmp/$PKG_NAME.spec"
fi

echo "
%description
$(grep '^\( \|Description:\)' /tmp/DEBIAN/control | sed -e 's/^\(Description:\)\? *//' -e 's/^\.$//' -e '/^Homepage/d')

%files
%config %{_sysconfdir}/$BASE_NAME
%{_sysconfdir}/cron.daily/*
%{_sysconfdir}/ld.so.conf.d/*
/opt/*
%config /opt/$BASE_NAME/etc/*.conf
%{_bindir}/*
%{_datadir}/bash-completion/completions/*
%doc %{_docdir}/*
%docdir %{_docdir}/%{name}
%{_mandir}/*/*
%docdir %{_mandir}/man?

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
" >> "/tmp/$PKG_NAME.spec"


NEWEST_FILE="$BASE_DIR/var/bdscan.inf"
find "$PKG_DIR" -newer "$NEWEST_FILE" -exec touch -hr "$NEWEST_FILE" "{}" \;

# sign RPM package
GPG_FILE="${ZIP_FILE%/*}/rpm-gpg-dsa.tgz"
if [ -f "$GPG_FILE" ]; then
    tar -xzf "$GPG_FILE" -C ~/
    gpg2 --batch --import ~/RPM-GPG-KEY*
else
    gpg2 --batch --passphrase '' --quick-generate-key "$PKG_OWNER" dsa1024 default 0

    gpg2 --export-secret-keys -a "$PKG_OWNER" > ~/RPM-GPG-KEY-bitdefender.asc
    gpg2 --export -a "$PKG_OWNER" > ~/RPM-GPG-KEY-bitdefender
    tar -czf "$GPG_FILE" -C ~/ RPM-GPG-KEY*
fi
#rpm --import ~/RPM-GPG-KEY*.pub

rpmbuild -bb --buildroot "$PKG_DIR" --nodeps --target "$ARCH-pc-linux" -D"%_target_platform $ARCH-pc-linux" "/tmp/$PKG_NAME.spec"
mv ~/rpmbuild/RPMS/$ARCH/*.rpm "${OUT_FILE%/*}/"
rpmsign --addsign -D'%_signature gpg' -D'%_gpgbin /usr/bin/gpg2' -D"%_gpg_path $HOME/.gnupg" -D"%_gpg_name ${PKG_OWNER% <*}" "$OUT_FILE"
rpm -qpi --provides -R --changelog --filetriggers --scripts -lv "$OUT_FILE" > "$OUT_FILE.txt" 2>&1

rm -rf "$PKG_DIR" ~/rpmbuild /tmp/*
