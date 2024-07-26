#!/bin/bash

URL="$1"
GITHUB_ENV="$2"
GITHUB_WORKSPACE="$3"
sudo chmod 777 -R ./*

# Lấy thông tin từ URL và chuẩn bị môi trường
zip_name=$(basename "$URL")
os_version=$(echo "$URL" | cut -d'/' -f4)
android_version=$(echo "$URL" | cut -d'_' -f5 | cut -d'.' -f1)
build_time=$(date)
build_utc=$(date -d "$build_time" +%s)

if [[ "$zip_name" == miui_* ]]; then
  device=$(echo "$zip_name" | cut -d'_' -f2)
  device=${device,,}
else
  echo "Firmware is not supported"
  exit 1
fi

echo "build_time=$build_time" >>"$GITHUB_ENV"
echo "version=$os_version" >>"$GITHUB_ENV"
echo "device_name=$device" >>"$GITHUB_ENV"

LIB_DIR="$GITHUB_WORKSPACE/lib"

sudo aria2c -x16 -j$(nproc) -U "Mozilla/5.0" -d "$GITHUB_WORKSPACE" "$URL"

echo "Decompressing payload.bin"
"$LIB_DIR/7z" e -aos "$zip_name" payload.bin -o"$GITHUB_WORKSPACE"
rm -rf "$GITHUB_WORKSPACE"/$zip_name

echo "Extracting payload.bin"
"$LIB_DIR/payload-dumper-go" -c 4 -o "$GITHUB_WORKSPACE" "payload.bin" >/dev/null 2>&1
rm -rf "$GITHUB_WORKSPACE/payload.bin"

echo "Extracting system_ext.img and system.img"
find "$GITHUB_WORKSPACE" -maxdepth 1 -type f -name '*.img' ! -name 'system_ext.img' ! -name 'system.img' -exec rm {} +

"$LIB_DIR/extract.erofs" -i "$GITHUB_WORKSPACE/system_ext.img" -o "$GITHUB_WORKSPACE" -x >/dev/null 2>&1
rm -rf "$GITHUB_WORKSPACE/system_ext.img"

"$LIB_DIR/extract.erofs" -i "$GITHUB_WORKSPACE/system.img" -o "$GITHUB_WORKSPACE" -x >/dev/null 2>&1
rm -rf "$GITHUB_WORKSPACE/system.img"

cp -rf "$GITHUB_WORKSPACE/system_ext/framework/miui-framework.jar" "$GITHUB_WORKSPACE/miui-framework.jar"
cp -rf "$GITHUB_WORKSPACE/system_ext/framework/miui-services.jar" "$GITHUB_WORKSPACE/miui-services.jar"
cp -rf "$GITHUB_WORKSPACE/system/system/framework/framework.jar" "$GITHUB_WORKSPACE/framework.jar"
cp -rf "$GITHUB_WORKSPACE/system/system/framework/services.jar" "$GITHUB_WORKSPACE/services.jar"

rm -rf "$GITHUB_WORKSPACE/system_ext"
rm -rf "$GITHUB_WORKSPACE/system"
