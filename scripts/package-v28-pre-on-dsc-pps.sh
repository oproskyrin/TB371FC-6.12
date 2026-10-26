#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kernel=/root/tb371fc-lenovo-4.19-v28-pre-on-dsc-pps-out/arch/arm64/boot/Image
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v27_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v27-idempotent-dsc-pps/tb371fc-arch-development-loader-v27-idempotent-dsc-pps-recovery.img
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v28-pre-on-dsc-pps
output_image="$output_dir/tb371fc-arch-development-loader-v28-pre-on-dsc-pps-recovery.img"
output_kernel="$output_dir/Image-v28-pre-on-dsc-pps"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

[[ -s $kernel ]]
[[ -s $stock_recovery ]]
[[ -s $v27_recovery ]]
[[ ! -e $output_image ]]
mkdir -p "$output_dir"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v27_recovery" --out "$stage/v27" --format info \
	>"$stage/v27-info.txt"

install -m 0644 "$kernel" "$output_kernel"
"$project_dir/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$stock_recovery" \
	"$output_kernel" \
	"$stage/v27/ramdisk" \
	"$stage/v27/dtb" \
	"$output_image"

printf 'Inherited v27 payload hashes:\n'
sha256sum "$stage/v27/ramdisk" "$stage/v27/dtb"
