#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kernel=/mnt/d/TB371FC-builds/arch-development-loader-v36-cont-splash-dual-flush/Image-v36-cont-splash-dual-flush
avdd_module=/mnt/d/TB371FC-builds/panel-avdd-hold-v13.ko
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v13_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v13/tb371fc-arch-development-loader-v13-recovery.img
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v37-early-avdd-hold
output_image="$output_dir/tb371fc-arch-development-loader-v37-early-avdd-hold-recovery.img"
output_ramdisk="$output_dir/initramfs-v37-early-avdd-hold.cpio.gz"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

[[ -s $kernel ]]
[[ -s $avdd_module ]]
[[ -s $stock_recovery ]]
[[ -s $v13_recovery ]]
[[ ! -e $output_image ]]
mkdir -p "$output_dir" "$stage/root"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v13_recovery" --out "$stage/v13" --format info \
	>"$stage/v13-info.txt"
(
	cd "$stage/root"
	gzip -dc "$stage/v13/ramdisk" | cpio -idmu 2>/dev/null
)

install -D -m 0644 "$avdd_module" \
	"$stage/root/lib/modules/4.19.325-cip134-st18-perf+/extra/panel-avdd-hold.ko"
install -D -m 0755 "$project_dir/initramfs/hold-panel-avdd" \
	"$stage/root/bin/hold-panel-avdd"

# Run after /run exists but before the rest of userspace can reach the late
# regulator sweep. A failed hold is fatal for this display-specific test.
sed -i '/mount -t tmpfs tmpfs \/tmp 2>\/dev\/null || true/a\hold-panel-avdd || exec setsid cttyhack sh' \
	"$stage/root/init"
grep -Fxq 'hold-panel-avdd || exec setsid cttyhack sh' "$stage/root/init"

(
	cd "$stage/root"
	find . -print0 | sort -z |
		cpio --null -o --format=newc --owner=0:0 2>/dev/null |
		gzip -9n >"$output_ramdisk"
)
gzip -t "$output_ramdisk"

export DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:SUN12x22 keep_bootcon ignore_loglevel initcall_debug rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused panic=-1 swiotlb=2048'
"$project_dir/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$stock_recovery" \
	"$kernel" \
	"$output_ramdisk" \
	"$stage/v13/dtb" \
	"$output_image"

sha256sum "$kernel" "$avdd_module" "$output_ramdisk" \
	"$stage/v13/dtb" "$output_image"
