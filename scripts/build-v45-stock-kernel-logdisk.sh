#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT=<repo>
V4_RAMDISK=/mnt/d/TB371FC-builds/arch-development-loader-v4/tb371fc-arch-development-loader-v4.cpio.gz
MODERN_RAMDISK=/root/v40-frame-boundary-ramdisk.cpio.gz
STOCK_PARTS=/mnt/d/TB371FC-builds/stock-recovery-unpacked
STOCK_RECOVERY="$PROJECT/artifacts/device-backup/lun0-recovery_b.bin"
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v45-stock-kernel-logdisk
OUTPUT_RAMDISK="$OUTPUT_ROOT/tb371fc-v45-stock-kernel-logdisk.cpio.gz"
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v45-stock-kernel-logdisk-recovery.img"

for input in "$V4_RAMDISK" "$MODERN_RAMDISK" "$STOCK_PARTS/kernel" \
	"$STOCK_PARTS/dtb" "$STOCK_RECOVERY"; do
	test -s "$input"
done
command -v mkfs.vfat >/dev/null
mkdir -p "$OUTPUT_ROOT"
test ! -e "$OUTPUT_RAMDISK"
test ! -e "$OUTPUT_IMAGE"

stage=$(mktemp -d)
modern=$(mktemp -d)
verify=$(mktemp -d)
trap 'rm -rf -- "$stage" "$modern" "$verify"' EXIT

(
	cd "$stage"
	gzip -dc "$V4_RAMDISK" | cpio -idmu 2>/dev/null
)
(
	cd "$modern"
	gzip -dc "$MODERN_RAMDISK" | cpio -idmu 2>/dev/null
)
install -m0755 "$PROJECT/initramfs/init-stock-kernel-logdisk-v45" "$stage/init"
install -m0755 "$modern/bin/drm-kms-smoketest" "$stage/bin/drm-kms-smoketest"
dd if=/dev/zero of="$stage/bin/v45-logdisk-template.img" bs=1M count=64 \
	status=none
mkfs.vfat -n TB371FCLOG "$stage/bin/v45-logdisk-template.img" >/dev/null

for binary in "$stage/bin/busybox" "$stage/bin/drm-kms-smoketest"; do
	file "$binary" | grep -q 'ARM aarch64.*statically linked'
done

(
	cd "$stage"
	find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 \
		2>/dev/null | gzip -9n >"$OUTPUT_RAMDISK"
)

DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel initcall_debug rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048' \
	bash "$PROJECT/scripts/build-diagnostic-recovery.sh" \
		/root/mkbootimg/mkbootimg.py \
		/root/mkbootimg/unpack_bootimg.py \
		/root/avb/avbtool.py \
		"$STOCK_RECOVERY" \
		"$STOCK_PARTS/kernel" \
		"$OUTPUT_RAMDISK" \
		"$STOCK_PARTS/dtb" \
		"$OUTPUT_IMAGE"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$OUTPUT_IMAGE" --out "$verify" --format=info \
	>"$OUTPUT_ROOT/unpack-info.txt"
cmp "$verify/kernel" "$STOCK_PARTS/kernel"
cmp "$verify/ramdisk" "$OUTPUT_RAMDISK"
cmp "$verify/dtb" "$STOCK_PARTS/dtb"
cmp "$verify/recovery_dtbo" "$STOCK_PARTS/recovery_dtbo"

sha256sum "$STOCK_PARTS/kernel" "$OUTPUT_RAMDISK" "$OUTPUT_IMAGE" \
	>"$OUTPUT_ROOT/SHA256SUMS"
cat "$OUTPUT_ROOT/SHA256SUMS"
