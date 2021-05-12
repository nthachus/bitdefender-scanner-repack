#!/bin/sh
set -xe

if echo "${1:-amd64}" | grep -q 64; then
    BITS=64
else
    BITS=32
fi

OUT_FILE="$(cd "`dirname "$0"`"; pwd)/cumulative$BITS.tgz"
if [ -f "$OUT_FILE" ]; then
    exit 0
fi

ZIP_FILE="${OUT_FILE%.*}.zip"
if [ ! -f "$ZIP_FILE" ]; then
    curl -Ro "$ZIP_FILE" "http://download.bitdefender.com/updates/update_av${BITS}bit/cumulative.zip"
fi
if [ ! -f "$ZIP_FILE.txt" ]; then
    unzip -l "$ZIP_FILE" > "$ZIP_FILE.txt"
    touch -r "$ZIP_FILE" "$ZIP_FILE.txt"
fi

WORK_DIR=/tmp/cumulative
mkdir -p "$WORK_DIR"
unzip -q "$ZIP_FILE" -d "$WORK_DIR/"

# @see threatscanner from bitdefender_ts_23
( cd "$WORK_DIR" && tar -czf "$OUT_FILE" --exclude '*.linux-*-wg' *.dll *.linux-* \
    */aspy*.cvd */auto.* */avxdisk.* */ceva*.* */disp.* */gvmscripts.* */lib.* */orice.* */tkn*.cvd */*.txt */variant.* */xlmrd.* )

tar -tzvf "$OUT_FILE" > "$OUT_FILE.txt"
touch -r "$ZIP_FILE" "$OUT_FILE" "$OUT_FILE.txt"

rm -rf "$WORK_DIR" /tmp/*
