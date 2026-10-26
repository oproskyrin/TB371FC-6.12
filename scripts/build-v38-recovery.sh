#!/bin/sh
set -eu

BUILD_ROOT=/root/tb371fc-lenovo-4.19-v38-splash-stock-pps-out
UNPACK_ROOT=/root/v38unpack
VERIFY_ROOT=/root/v38verify
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v38-splash-stock-pps
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v38-splash-stock-pps-recovery.img"

install -m 0644 "$BUILD_ROOT/arch/arm64/boot/Image" "$UNPACK_ROOT/kernel"
mkdir -p "$OUTPUT_ROOT"
rm -rf "$VERIFY_ROOT"
mkdir -p "$VERIFY_ROOT"

# Arguments were emitted with shell quoting by unpack_bootimg.py from V37.
# Evaluate only this locally generated argument file so the cmdline remains one
# argument instead of being split at spaces.
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
