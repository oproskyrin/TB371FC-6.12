#!/bin/sh
set -eu

BUILD_ROOT=/root/tb371fc-lenovo-4.19-v39-stock-post-on-out
UNPACK_ROOT=/root/v38unpack
VERIFY_ROOT=/root/v39verify
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v39-stock-post-on
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v39-stock-post-on-recovery.img"

install -m 0644 "$BUILD_ROOT/arch/arm64/boot/Image" "$UNPACK_ROOT/kernel"
mkdir -p "$OUTPUT_ROOT"
rm -rf "$VERIFY_ROOT"
mkdir -p "$VERIFY_ROOT"

# Reuse the locally generated and already verified V37/V38 boot metadata.
eval "set -- $(cat /root/v38-mkargs)"
python3 /root/mkbootimg/mkbootimg.py "$@" \
    --kernel "$UNPACK_ROOT/kernel" \
    --output "$OUTPUT_IMAGE"

python3 /root/mkbootimg/unpack_bootimg.py \
    --boot_img "$OUTPUT_IMAGE" \
    --out "$VERIFY_ROOT" \
    --format=info > "$OUTPUT_ROOT/unpack-info.txt"

cmp "$VERIFY_ROOT/kernel" "$BUILD_ROOT/arch/arm64/boot/Image"
cmp "$VERIFY_ROOT/ramdisk" "$UNPACK_ROOT/ramdisk"
cmp "$VERIFY_ROOT/dtb" "$UNPACK_ROOT/dtb"
cmp "$VERIFY_ROOT/recovery_dtbo" "$UNPACK_ROOT/recovery_dtbo"

truncate -s 104857600 "$OUTPUT_IMAGE"
sha256sum "$BUILD_ROOT/arch/arm64/boot/Image" "$OUTPUT_IMAGE"
