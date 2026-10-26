#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kernel=/root/tb371fc-lenovo-4.19-v35-panel-status-read-out/arch/arm64/boot/Image
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v34_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v34-pre-on-pps-only/tb371fc-arch-development-loader-v34-pre-on-pps-only-recovery.img
v34_ramdisk=/mnt/d/TB371FC-builds/arch-development-loader-v34-pre-on-pps-only/initramfs-v34-pre-on-pps-only-kexec.cpio.gz
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v35-panel-status-read
output_image="$output_dir/tb371fc-arch-development-loader-v35-panel-status-read-recovery.img"
output_kernel="$output_dir/Image-v35-panel-status-read"
output_ramdisk="$output_dir/initramfs-v35-panel-status-read-kexec.cpio.gz"
output_dtb="$output_dir/dtb-v35-stock-exact"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

for input in "$kernel" "$stock_recovery" "$v34_recovery" "$v34_ramdisk"; do
	[[ -s $input ]] || { echo "Missing input: $input" >&2; exit 1; }
done
[[ ! -e $output_image ]]
mkdir -p "$output_dir"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v34_recovery" --out "$stage/v34" --format info \
	>"$stage/v34-info.txt"

install -m 0644 "$kernel" "$output_kernel"
install -m 0644 "$v34_ramdisk" "$output_ramdisk"
install -m 0644 "$stage/v34/dtb" "$output_dtb"
"$project_dir/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$stock_recovery" \
	"$output_kernel" \
	"$output_ramdisk" \
	"$output_dtb" \
	"$output_image"

sha256sum "$output_kernel" "$output_ramdisk" "$output_dtb" "$output_image"
