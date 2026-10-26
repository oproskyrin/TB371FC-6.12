#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kernel=/root/tb371fc-lenovo-4.19-v32-nt36532-vendor-dsc-out/arch/arm64/boot/Image
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v28_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v28-pre-on-dsc-pps/tb371fc-arch-development-loader-v28-pre-on-dsc-pps-recovery.img
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v32-nt36532-vendor-dsc
output_image="$output_dir/tb371fc-arch-development-loader-v32-nt36532-vendor-dsc-recovery.img"
output_kernel="$output_dir/Image-v32-nt36532-vendor-dsc"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

[[ -s $kernel ]]
[[ -s $stock_recovery ]]
[[ -s $v28_recovery ]]
[[ ! -e $output_image ]]
mkdir -p "$output_dir"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v28_recovery" --out "$stage/v28" --format info \
	>"$stage/v28-info.txt"

install -m 0644 "$kernel" "$output_kernel"
"$project_dir/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$stock_recovery" \
	"$output_kernel" \
	"$stage/v28/ramdisk" \
	"$stage/v28/dtb" \
	"$output_image"

sha256sum "$output_kernel" "$stage/v28/ramdisk" "$stage/v28/dtb" "$output_image"
