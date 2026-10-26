#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_tree=/root/tb371fc-lenovo-4.19-v33-per-link-dsc-pps-src
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v33-per-link-dsc-pps
image="$output_dir/tb371fc-arch-development-loader-v33-per-link-dsc-pps-recovery.img"
kernel="$output_dir/Image-v33-per-link-dsc-pps"
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v32_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v32-nt36532-vendor-dsc/tb371fc-arch-development-loader-v32-nt36532-vendor-dsc-recovery.img
expected_sha256=c5fe930e71e1bc7267527c8723ab04bd1f80f6a7b6343fbbcdd0d042dc5b8c43
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v32_recovery" --out "$stage/v32" --format info \
	>"$stage/v32-info.txt"

"$project_dir/scripts/verify-diagnostic-recovery.sh" \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$image" \
	"$stock_recovery" \
	"$kernel" \
	"$stage/v32/ramdisk" \
	"$stage/v32/dtb" \
	"$expected_sha256"

display="$source_tree/techpack/display/msm/dsi/dsi_display.c"
panel="$source_tree/techpack/display/msm/dsi/dsi_panel.c"
test "$(grep -c 'TB371FC diagnostic PPS uses per-link pic_width' "$display")" -eq 2
! grep -A8 'TB371FC pre-ON PPS:' "$display" | grep -q 'per_link_pic_width \* display->ctrl_count'
! grep -A10 'TB371FC display enable PPS:' "$display" | grep -q 'per_link_pic_width \* display->ctrl_count'
grep -q 'tb371fc_nt36532_dsc_write(panel, 0x90, 0x03)' "$panel"
grep -q 'tb371fc_nt36532_dsc_write(panel, 0x9d, 0x01)' "$panel"
grep -q 'TB371FC diagnostic PPS uses per-link' "$kernel"
grep -q 'TB371FC NT36532 vendor DSC enable complete' "$kernel"

echo 'Verified v33: exact v32 ramdisk/DTB, per-link PPS width and retained NT36532 command order.'
sha256sum "$kernel" "$image"
