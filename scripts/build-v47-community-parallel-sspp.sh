#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT=<repo>
COMMUNITY_KERNEL=/root/tb371fc-desktop-working-out/arch/arm64/boot/Image
V45_RAMDISK=/mnt/d/TB371FC-builds/arch-development-loader-v45-stock-kernel-logdisk/tb371fc-v45-stock-kernel-logdisk.cpio.gz
STOCK_PARTS=/mnt/d/TB371FC-builds/stock-recovery-unpacked
STOCK_RECOVERY="$PROJECT/artifacts/device-backup/lun0-recovery_b.bin"
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v47-community-parallel-sspp
PATCHED_DTB_ENTRY="$OUTPUT_ROOT/dtb-entry-00-sspp-1880.dtb"
PATCHED_DTB="$OUTPUT_ROOT/dtb-community-sspp-1880.img"
PATCHED_DTBO_ENTRY="$OUTPUT_ROOT/dtbo-entry-02-avdd-always-on.dtbo"
PATCHED_DTBO="$OUTPUT_ROOT/recovery-dtbo-avdd-always-on.img"
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v47-community-parallel-sspp-recovery.img"
SDE=/soc/qcom,mdss_mdp@ae00000
LINEWIDTH_LIMITS="$SDE/qcom,sde-limits/qcom,sde-linewidth-limits"
AVDD=/fragment@42/__overlay__/display_gpio_regulator@1

for input in "$COMMUNITY_KERNEL" "$V45_RAMDISK" "$STOCK_PARTS/dtb" \
	"$STOCK_PARTS/recovery_dtbo" "$STOCK_RECOVERY"; do
	test -s "$input"
done
mkdir -p "$OUTPUT_ROOT"
test ! -e "$PATCHED_DTB_ENTRY"
test ! -e "$PATCHED_DTB"
test ! -e "$PATCHED_DTBO_ENTRY"
test ! -e "$PATCHED_DTBO"
test ! -e "$OUTPUT_IMAGE"

dtb_extract=$(mktemp -d)
dtb_verify=$(mktemp -d)
dtbo_extract=$(mktemp -d)
dtbo_verify=$(mktemp -d)
image_verify=$(mktemp -d)
trap 'rm -rf -- "$dtb_extract" "$dtb_verify" "$dtbo_extract" "$dtbo_verify" "$image_verify"' EXIT

python3 "$PROJECT/scripts/extract-concatenated-dtb.py" \
	"$STOCK_PARTS/dtb" "$dtb_extract" >"$OUTPUT_ROOT/stock-dtb-layout.txt"
cp "$dtb_extract/entry-00.dtb" "$PATCHED_DTB_ENTRY"
fdtput -t x "$PATCHED_DTB_ENTRY" "$SDE" qcom,sde-sspp-linewidth 758
fdtput -t x "$PATCHED_DTB_ENTRY" "$LINEWIDTH_LIMITS" qcom,sde-limit-values \
	1 758 5 a00 2 1000 9 440
test "$(fdtget -t x "$PATCHED_DTB_ENTRY" "$SDE" qcom,sde-sspp-linewidth)" = 758
test "$(fdtget -t x "$PATCHED_DTB_ENTRY" "$LINEWIDTH_LIMITS" qcom,sde-limit-values)" = \
	"1 758 5 a00 2 1000 9 440"
test "$(fdtget -t x "$dtb_extract/entry-00.dtb" "$SDE" qcom,sde-sspp-linewidth)" = 1000

python3 "$PROJECT/scripts/replace-concatenated-dtb-entry.py" \
	"$STOCK_PARTS/dtb" 0 "$PATCHED_DTB_ENTRY" "$PATCHED_DTB"
python3 "$PROJECT/scripts/extract-concatenated-dtb.py" \
	"$PATCHED_DTB" "$dtb_verify" >"$OUTPUT_ROOT/patched-dtb-layout.txt"
cmp "$PATCHED_DTB_ENTRY" "$dtb_verify/entry-00.dtb"
for index in 01 02 03; do
	cmp "$dtb_extract/entry-$index.dtb" "$dtb_verify/entry-$index.dtb"
done

python3 "$PROJECT/scripts/extract-dtbo.py" \
	"$STOCK_PARTS/recovery_dtbo" "$dtbo_extract" >"$OUTPUT_ROOT/stock-dtbo-layout.txt"
cp "$dtbo_extract/entry-02.dtbo" "$PATCHED_DTBO_ENTRY"
fdtput -p "$PATCHED_DTBO_ENTRY" "$AVDD" regulator-always-on
fdtget -p "$PATCHED_DTBO_ENTRY" "$AVDD" | grep -qx regulator-always-on
python3 "$PROJECT/scripts/replace-dtbo-entry.py" \
	"$STOCK_PARTS/recovery_dtbo" 2 "$PATCHED_DTBO_ENTRY" "$PATCHED_DTBO"
python3 "$PROJECT/scripts/extract-dtbo.py" \
	"$PATCHED_DTBO" "$dtbo_verify" >"$OUTPUT_ROOT/patched-dtbo-layout.txt"
cmp "$PATCHED_DTBO_ENTRY" "$dtbo_verify/entry-02.dtbo"
for index in 00 01 03 04 05 06 07 08 09 10 11 12 13; do
	cmp "$dtbo_extract/entry-$index.dtbo" "$dtbo_verify/entry-$index.dtbo"
done

RECOVERY_DTBO="$PATCHED_DTBO" \
DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel initcall_debug rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 msm_drm.sdecustom=0 video=Virtual-1:d' \
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
	--boot_img "$OUTPUT_IMAGE" --out "$image_verify" --format=info \
	>"$OUTPUT_ROOT/unpack-info.txt"
cmp "$image_verify/kernel" "$COMMUNITY_KERNEL"
cmp "$image_verify/ramdisk" "$V45_RAMDISK"
cmp "$image_verify/dtb" "$PATCHED_DTB"
cmp "$image_verify/recovery_dtbo" "$PATCHED_DTBO"

sha256sum "$COMMUNITY_KERNEL" "$V45_RAMDISK" "$PATCHED_DTB_ENTRY" \
	"$PATCHED_DTB" "$PATCHED_DTBO_ENTRY" "$PATCHED_DTBO" "$OUTPUT_IMAGE" \
	>"$OUTPUT_ROOT/SHA256SUMS"
cat "$OUTPUT_ROOT/SHA256SUMS"
