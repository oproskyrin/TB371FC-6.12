#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT=<repo>
V47_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v47-community-parallel-sspp
COMMUNITY_KERNEL=/root/tb371fc-desktop-working-out/arch/arm64/boot/Image
V45_RAMDISK=/mnt/d/TB371FC-builds/arch-development-loader-v45-stock-kernel-logdisk/tb371fc-v45-stock-kernel-logdisk.cpio.gz
STOCK_RECOVERY="$PROJECT/artifacts/device-backup/lun0-recovery_b.bin"
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v48-community-parallel-sspp-kmslog
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v48-community-parallel-sspp-kmslog-recovery.img"
PATCHED_DTB="$V47_ROOT/dtb-community-sspp-1880.img"
PATCHED_DTBO="$V47_ROOT/recovery-dtbo-avdd-always-on.img"

for input in "$COMMUNITY_KERNEL" "$V45_RAMDISK" "$PATCHED_DTB" \
	"$PATCHED_DTBO" "$STOCK_RECOVERY"; do
	test -s "$input"
done
mkdir -p "$OUTPUT_ROOT"
test ! -e "$OUTPUT_IMAGE"

verify=$(mktemp -d)
trap 'rm -rf -- "$verify"' EXIT

RECOVERY_DTBO="$PATCHED_DTBO" \
DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel initcall_debug rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 msm_drm.sdecustom=0 video=Virtual-1:d drm.debug=0x04' \
	bash "$PROJECT/scripts/build-diagnostic-recovery.sh" \
		/root/mkbootimg/mkbootimg.py \
		/root/mkbootimg/unpack_bootimg.py \
		/root/avb/avbtool.py \
		"$STOCK_RECOVERY" \
		"$COMMUNITY_KERNEL" \
		"$V45_RAMDISK" \
		"$PATCHED_DTB" \
		"$OUTPUT_IMAGE"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$OUTPUT_IMAGE" --out "$verify" --format=info \
	>"$OUTPUT_ROOT/unpack-info.txt"
cmp "$verify/kernel" "$COMMUNITY_KERNEL"
cmp "$verify/ramdisk" "$V45_RAMDISK"
cmp "$verify/dtb" "$PATCHED_DTB"
cmp "$verify/recovery_dtbo" "$PATCHED_DTBO"
grep -q 'drm.debug=0x04' "$OUTPUT_ROOT/unpack-info.txt"

sha256sum "$COMMUNITY_KERNEL" "$V45_RAMDISK" "$PATCHED_DTB" \
	"$PATCHED_DTBO" "$OUTPUT_IMAGE" >"$OUTPUT_ROOT/SHA256SUMS"
cat "$OUTPUT_ROOT/SHA256SUMS"
