#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kernel=/root/tb371fc-lenovo-4.19-v36-cont-splash-dual-flush-out/arch/arm64/boot/Image
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v13_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v13/tb371fc-arch-development-loader-v13-recovery.img
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v36-cont-splash-dual-flush
output_image="$output_dir/tb371fc-arch-development-loader-v36-cont-splash-dual-flush-recovery.img"
output_kernel="$output_dir/Image-v36-cont-splash-dual-flush"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

[[ -s $kernel ]]
[[ -s $stock_recovery ]]
[[ -s $v13_recovery ]]
[[ ! -e $output_image ]]
mkdir -p "$output_dir"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v13_recovery" --out "$stage/v13" --format info \
	>"$stage/v13-info.txt"

install -m 0644 "$kernel" "$output_kernel"
export DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:SUN12x22 keep_bootcon ignore_loglevel initcall_debug rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048'
"$project_dir/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$stock_recovery" \
	"$output_kernel" \
	"$stage/v13/ramdisk" \
	"$stage/v13/dtb" \
	"$output_image"

cmp "$stage/v13/ramdisk" <(python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$output_image" --out "$stage/verify" --format info \
	>/dev/null; cat "$stage/verify/ramdisk")
sha256sum "$output_kernel" "$stage/v13/ramdisk" "$stage/v13/dtb" "$output_image"
