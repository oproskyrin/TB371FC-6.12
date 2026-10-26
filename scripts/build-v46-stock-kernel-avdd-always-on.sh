#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
V45_RAMDISK=/mnt/d/TB371FC-builds/arch-development-loader-v45-stock-kernel-logdisk/tb371fc-v45-stock-kernel-logdisk.cpio.gz
STOCK_PARTS=/mnt/d/TB371FC-builds/stock-recovery-unpacked
STOCK_RECOVERY="$PROJECT/artifacts/device-backup/lun0-recovery_b.bin"
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v46-stock-kernel-avdd-always-on
PATCHED_ENTRY="$OUTPUT_ROOT/entry-02-avdd-always-on.dtbo"
PATCHED_DTBO="$OUTPUT_ROOT/recovery-dtbo-avdd-always-on.img"
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v46-stock-kernel-avdd-always-on-recovery.img"
NODE=/fragment@42/__overlay__/display_gpio_regulator@1

for input in "$V45_RAMDISK" "$STOCK_PARTS/kernel" "$STOCK_PARTS/dtb" \
	"$STOCK_PARTS/recovery_dtbo" "$STOCK_RECOVERY"; do
	test -s "$input"
done
mkdir -p "$OUTPUT_ROOT"
test ! -e "$PATCHED_ENTRY"
test ! -e "$PATCHED_DTBO"
test ! -e "$OUTPUT_IMAGE"

extract=$(mktemp -d)
verify=$(mktemp -d)
reextract=$(mktemp -d)
trap 'rm -rf -- "$extract" "$verify" "$reextract"' EXIT

python3 "$PROJECT/scripts/extract-dtbo.py" \
	"$STOCK_PARTS/recovery_dtbo" "$extract" >"$OUTPUT_ROOT/stock-dtbo-layout.txt"
cp "$extract/entry-02.dtbo" "$PATCHED_ENTRY"
fdtput -p "$PATCHED_ENTRY" "$NODE" regulator-always-on
fdtget -p "$PATCHED_ENTRY" "$NODE" | grep -qx regulator-always-on
if fdtget -p "$extract/entry-02.dtbo" "$NODE" | grep -qx regulator-always-on; then
	echo 'Stock entry unexpectedly already has regulator-always-on' >&2
	exit 1
fi

python3 "$PROJECT/scripts/replace-dtbo-entry.py" \
	"$STOCK_PARTS/recovery_dtbo" 2 "$PATCHED_ENTRY" "$PATCHED_DTBO"
python3 "$PROJECT/scripts/extract-dtbo.py" \
	"$PATCHED_DTBO" "$reextract" >"$OUTPUT_ROOT/patched-dtbo-layout.txt"
cmp "$PATCHED_ENTRY" "$reextract/entry-02.dtbo"
for index in 00 01 03 04 05 06 07 08 09 10 11 12 13; do
	cmp "$extract/entry-$index.dtbo" "$reextract/entry-$index.dtbo"
done

RECOVERY_DTBO="$PATCHED_DTBO" \
DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel initcall_debug rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048' \
	bash "$PROJECT/scripts/build-diagnostic-recovery.sh" \
		/root/mkbootimg/mkbootimg.py \
		/root/mkbootimg/unpack_bootimg.py \
		/root/avb/avbtool.py \
		"$STOCK_RECOVERY" \
		"$STOCK_PARTS/kernel" \
		"$V45_RAMDISK" \
		"$STOCK_PARTS/dtb" \
		"$OUTPUT_IMAGE"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$OUTPUT_IMAGE" --out "$verify" --format=info \
	>"$OUTPUT_ROOT/unpack-info.txt"
cmp "$verify/kernel" "$STOCK_PARTS/kernel"
cmp "$verify/ramdisk" "$V45_RAMDISK"
cmp "$verify/dtb" "$STOCK_PARTS/dtb"
cmp "$verify/recovery_dtbo" "$PATCHED_DTBO"

sha256sum "$STOCK_PARTS/kernel" "$V45_RAMDISK" "$PATCHED_ENTRY" \
	"$PATCHED_DTBO" "$OUTPUT_IMAGE" >"$OUTPUT_ROOT/SHA256SUMS"
cat "$OUTPUT_ROOT/SHA256SUMS"
