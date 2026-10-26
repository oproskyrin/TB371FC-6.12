#!/bin/sh
set -eu

BUILD_ROOT=/root/tb371fc-lenovo-4.19-v40-frame-boundary-out
UNPACK_ROOT=/root/v38unpack
RAMDISK=/root/v40-frame-boundary-ramdisk.cpio.gz
VERIFY_ROOT=/root/v40verify
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v40-frame-boundary
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v40-frame-boundary-recovery.img"

test -s "$BUILD_ROOT/arch/arm64/boot/Image"
test -s "$RAMDISK"
mkdir -p "$OUTPUT_ROOT"
rm -rf "$VERIFY_ROOT"
mkdir -p "$VERIFY_ROOT"

eval "set -- $(cat /root/v38-mkargs)"
python3 /root/mkbootimg/mkbootimg.py "$@" \
	--kernel "$BUILD_ROOT/arch/arm64/boot/Image" \
	--ramdisk "$RAMDISK" \
	--output "$OUTPUT_IMAGE"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$OUTPUT_IMAGE" \
	--out "$VERIFY_ROOT" \
	--format=info > "$OUTPUT_ROOT/unpack-info.txt"

cmp "$VERIFY_ROOT/kernel" "$BUILD_ROOT/arch/arm64/boot/Image"
cmp "$VERIFY_ROOT/ramdisk" "$RAMDISK"
cmp "$VERIFY_ROOT/dtb" "$UNPACK_ROOT/dtb"
cmp "$VERIFY_ROOT/recovery_dtbo" "$UNPACK_ROOT/recovery_dtbo"

truncate -s 104857600 "$OUTPUT_IMAGE"
sha256sum "$BUILD_ROOT/arch/arm64/boot/Image" "$RAMDISK" "$OUTPUT_IMAGE"
