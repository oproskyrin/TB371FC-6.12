#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
COMMUNITY_KERNEL=/root/tb371fc-desktop-working-out-v49/arch/arm64/boot/Image
V45_RAMDISK=/mnt/d/TB371FC-builds/arch-development-loader-v45-stock-kernel-logdisk/tb371fc-v45-stock-kernel-logdisk.cpio.gz
V47_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v47-community-parallel-sspp
STOCK_RECOVERY="$PROJECT/artifacts/device-backup/lun0-recovery_b.bin"
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v49-community-simplefb-console
OUTPUT_RAMDISK="$OUTPUT_ROOT/tb371fc-v49-simplefb-logdisk.cpio.gz"
PATCHED_DTB_ENTRY="$OUTPUT_ROOT/dtb-entry-00-sspp-simplefb.dtb"
PATCHED_DTB="$OUTPUT_ROOT/dtb-community-sspp-simplefb.img"
PATCHED_DTBO="$V47_ROOT/recovery-dtbo-avdd-always-on.img"
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v49-community-simplefb-console-recovery.img"
PANEL=/soc/qcom,mdss_mdp@ae00000/qcom,mdss_dsi_panel_spinel_tianma_nt36532_dsc_3k_video
FB=/chosen/framebuffer@9c000000
DISPCC=/soc/qcom,dispcc@af00000
GCC=/soc/qcom,gcc@100000
MDSS_GDSC=/soc/qcom,gdsc@af03000

for input in "$COMMUNITY_KERNEL" "$V45_RAMDISK" "$V47_ROOT/dtb-community-sspp-1880.img" \
	"$PATCHED_DTBO" "$STOCK_RECOVERY"; do
	test -s "$input"
done
mkdir -p "$OUTPUT_ROOT"
test ! -e "$OUTPUT_RAMDISK"
test ! -e "$PATCHED_DTB_ENTRY"
test ! -e "$PATCHED_DTB"
test ! -e "$OUTPUT_IMAGE"

ramdisk_stage=$(mktemp -d)
dtb_extract=$(mktemp -d)
dtb_verify=$(mktemp -d)
image_verify=$(mktemp -d)
trap 'rm -rf -- "$ramdisk_stage" "$dtb_extract" "$dtb_verify" "$image_verify"' EXIT

(
	cd "$ramdisk_stage"
	gzip -dc "$V45_RAMDISK" | cpio -idmu 2>/dev/null
)
install -m0755 "$PROJECT/initramfs/init-community-simplefb-v49" "$ramdisk_stage/init"
(
	cd "$ramdisk_stage"
	find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 \
		2>/dev/null | gzip -9n >"$OUTPUT_RAMDISK"
)

python3 "$PROJECT/scripts/extract-concatenated-dtb.py" \
	"$V47_ROOT/dtb-community-sspp-1880.img" "$dtb_extract" \
	>"$OUTPUT_ROOT/input-dtb-layout.txt"
cp "$dtb_extract/entry-00.dtb" "$PATCHED_DTB_ENTRY"

fdtput -t s "$PATCHED_DTB_ENTRY" /aliases display0 "$PANEL"
fdtput -t s "$PATCHED_DTB_ENTRY" /chosen stdout-path display0
fdtput -t x "$PATCHED_DTB_ENTRY" /chosen '#address-cells' 2
fdtput -t x "$PATCHED_DTB_ENTRY" /chosen '#size-cells' 2
fdtput -p "$PATCHED_DTB_ENTRY" /chosen ranges
fdtput -c -p "$PATCHED_DTB_ENTRY" "$FB"
fdtput -t s "$PATCHED_DTB_ENTRY" "$FB" compatible simple-framebuffer
fdtput -t x "$PATCHED_DTB_ENTRY" "$FB" reg 0 9c000000 0 2300000
fdtput -t x "$PATCHED_DTB_ENTRY" "$FB" width b80
fdtput -t x "$PATCHED_DTB_ENTRY" "$FB" height 730
fdtput -t x "$PATCHED_DTB_ENTRY" "$FB" stride 2e00
fdtput -t s "$PATCHED_DTB_ENTRY" "$FB" format a8r8g8b8
fdtput -t s "$PATCHED_DTB_ENTRY" "$FB" status okay
fdtput -t s "$PATCHED_DTB_ENTRY" "$FB" display "$PANEL"

# Match the community simplefb clock hold list exactly.  The downstream
# Android DT represents MDSS_GDSC as a regulator rather than a generic power
# domain, so hold its vendor regulator through simplefb's *-supply support.
dispcc_phandle=$(fdtget -t x "$PATCHED_DTB_ENTRY" "$DISPCC" phandle)
gcc_phandle=$(fdtget -t x "$PATCHED_DTB_ENTRY" "$GCC" phandle)
mdss_gdsc_phandle=$(fdtget -t x "$PATCHED_DTB_ENTRY" "$MDSS_GDSC" phandle)
fdtput -t x "$PATCHED_DTB_ENTRY" "$FB" clocks \
	"$dispcc_phandle" 0 \
	"$gcc_phandle" 19 \
	"$gcc_phandle" 1a \
	"$dispcc_phandle" 36 \
	"$dispcc_phandle" 2a \
	"$dispcc_phandle" 2 \
	"$dispcc_phandle" 5 \
	"$dispcc_phandle" 2e \
	"$dispcc_phandle" 26
fdtput -t x "$PATCHED_DTB_ENTRY" "$FB" mdss-supply \
	"$mdss_gdsc_phandle"

test "$(fdtget -t s "$PATCHED_DTB_ENTRY" "$FB" compatible)" = simple-framebuffer
test "$(fdtget -t x "$PATCHED_DTB_ENTRY" /chosen '#address-cells')" = 2
test "$(fdtget -t x "$PATCHED_DTB_ENTRY" /chosen '#size-cells')" = 2
test "$(fdtget -t x "$PATCHED_DTB_ENTRY" "$FB" reg)" = "0 9c000000 0 2300000"
test "$(fdtget -t x "$PATCHED_DTB_ENTRY" "$FB" width)" = b80
test "$(fdtget -t x "$PATCHED_DTB_ENTRY" "$FB" height)" = 730
test "$(fdtget -t x "$PATCHED_DTB_ENTRY" "$FB" stride)" = 2e00
test "$(fdtget -t s "$PATCHED_DTB_ENTRY" "$FB" format)" = a8r8g8b8
test "$(fdtget -t s "$PATCHED_DTB_ENTRY" /aliases display0)" = "$PANEL"
test "$(fdtget -t x "$PATCHED_DTB_ENTRY" "$FB" clocks)" = \
	"$dispcc_phandle 0 $gcc_phandle 19 $gcc_phandle 1a $dispcc_phandle 36 $dispcc_phandle 2a $dispcc_phandle 2 $dispcc_phandle 5 $dispcc_phandle 2e $dispcc_phandle 26"
test "$(fdtget -t x "$PATCHED_DTB_ENTRY" "$FB" mdss-supply)" = \
	"$mdss_gdsc_phandle"

python3 "$PROJECT/scripts/replace-concatenated-dtb-entry.py" \
	"$V47_ROOT/dtb-community-sspp-1880.img" 0 "$PATCHED_DTB_ENTRY" "$PATCHED_DTB"
python3 "$PROJECT/scripts/extract-concatenated-dtb.py" \
	"$PATCHED_DTB" "$dtb_verify" >"$OUTPUT_ROOT/output-dtb-layout.txt"
cmp "$PATCHED_DTB_ENTRY" "$dtb_verify/entry-00.dtb"
for index in 01 02 03; do
	cmp "$dtb_extract/entry-$index.dtb" "$dtb_verify/entry-$index.dtb"
done

RECOVERY_DTBO="$PATCHED_DTBO" \
DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 msm_drm.sdecustom=0 video=Virtual-1:d fbcon=font:SUN12x22 fbcon=nodefer' \
	bash "$PROJECT/scripts/build-diagnostic-recovery.sh" \
		/root/mkbootimg/mkbootimg.py \
		/root/mkbootimg/unpack_bootimg.py \
		/root/avb/avbtool.py \
		"$STOCK_RECOVERY" \
		"$COMMUNITY_KERNEL" \
		"$OUTPUT_RAMDISK" \
		"$PATCHED_DTB" \
		"$OUTPUT_IMAGE"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$OUTPUT_IMAGE" --out "$image_verify" --format=info \
	>"$OUTPUT_ROOT/unpack-info.txt"
cmp "$image_verify/kernel" "$COMMUNITY_KERNEL"
cmp "$image_verify/ramdisk" "$OUTPUT_RAMDISK"
cmp "$image_verify/dtb" "$PATCHED_DTB"
cmp "$image_verify/recovery_dtbo" "$PATCHED_DTBO"
grep -q 'fbcon=font:SUN12x22 fbcon=nodefer' "$OUTPUT_ROOT/unpack-info.txt"

sha256sum "$COMMUNITY_KERNEL" "$OUTPUT_RAMDISK" "$PATCHED_DTB_ENTRY" \
	"$PATCHED_DTB" "$PATCHED_DTBO" "$OUTPUT_IMAGE" >"$OUTPUT_ROOT/SHA256SUMS"
cat "$OUTPUT_ROOT/SHA256SUMS"
