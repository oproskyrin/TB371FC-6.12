#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v28-pre-on-dsc-pps
image="$output_dir/tb371fc-arch-development-loader-v28-pre-on-dsc-pps-recovery.img"
kernel="$output_dir/Image-v28-pre-on-dsc-pps"
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v27_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v27-idempotent-dsc-pps/tb371fc-arch-development-loader-v27-idempotent-dsc-pps-recovery.img
expected_sha256=9243cf7cf261fb777a2d4889e1e56cb73f243ac37e009f2b282c0749189e37f4
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v27_recovery" --out "$stage/v27" --format info \
	>"$stage/v27-info.txt"

"$project_dir/scripts/verify-diagnostic-recovery.sh" \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$image" \
	"$stock_recovery" \
	"$kernel" \
	"$stage/v27/ramdisk" \
	"$stage/v27/dtb" \
	"$expected_sha256"
