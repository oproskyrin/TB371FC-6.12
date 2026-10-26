#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_RAMDISK=/root/v40-frame-boundary-ramdisk.cpio.gz
STOCK_PARTS=/mnt/d/TB371FC-builds/stock-recovery-unpacked
STOCK_RECOVERY="$PROJECT/artifacts/device-backup/lun0-recovery_b.bin"
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v43-stock-kernel-control
OUTPUT_RAMDISK="$OUTPUT_ROOT/tb371fc-v43-stock-kernel-control.cpio.gz"
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v43-stock-kernel-control-recovery.img"

test -s "$BASE_RAMDISK"
test -s "$STOCK_PARTS/kernel"
test -s "$STOCK_PARTS/dtb"
test -s "$STOCK_RECOVERY"
mkdir -p "$OUTPUT_ROOT"
test ! -e "$OUTPUT_RAMDISK"
test ! -e "$OUTPUT_IMAGE"

stage=$(mktemp -d)
verify=$(mktemp -d)
trap 'rm -rf -- "$stage" "$verify"' EXIT

(
	cd "$stage"
	gzip -dc "$BASE_RAMDISK" | cpio -idmu 2>/dev/null
)
install -m0755 "$PROJECT/initramfs/init-stock-kernel-control" "$stage/init"
aarch64-linux-gnu-gcc -static -Os -s -Wall -Wextra \
	-o "$stage/bin/reboot-bootloader-userspace" \
	"$PROJECT/diagnostics/reboot-bootloader-userspace.c"
file "$stage/bin/reboot-bootloader-userspace" | \
	grep -q 'ARM aarch64.*statically linked'

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
