#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build_dir=${BUILD_DIR:-/root/tb371fc-linux-7.1.7-display-test-out}
output_dir=${OUTPUT_DIR:-/mnt/d/TB371FC-builds/mainline-7.1.7-native-display-test}
output="$output_dir/tb371fc-mainline-7.1.7-native-display-recovery.img"
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
initramfs="$output_dir/tb371fc-mainline-display-initramfs.cpio.gz"
kernel="$build_dir/arch/arm64/boot/Image"
dtb="$build_dir/arch/arm64/boot/dts/qcom/sm8250-lenovo-tb371fc-display-test.dtb"

for input in "$stock_recovery" "$initramfs" "$kernel" "$dtb"; do
	[[ -s $input ]] || {
		echo "Missing package input: $input" >&2
		exit 1
	}
done
[[ ! -e $output ]] || {
	echo "Refusing to overwrite existing recovery: $output" >&2
	exit 1
}

export DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel initcall_debug drm.debug=0x1ff log_buf_len=4M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused panic=-1 swiotlb=2048'

"$project_dir/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$stock_recovery" \
	"$kernel" \
	"$initramfs" \
	"$dtb" \
	"$output"
