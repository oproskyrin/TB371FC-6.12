#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
kernel=/root/tb371fc-lenovo-4.19-v29-kexec-bridge-out/arch/arm64/boot/Image
kexec_binary=/root/kexec-tools-build-aarch64/build/sbin/kexec
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v28_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v28-pre-on-dsc-pps/tb371fc-arch-development-loader-v28-pre-on-dsc-pps-recovery.img
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v29-kexec-bridge
output_image="$output_dir/tb371fc-arch-development-loader-v29-kexec-bridge-recovery.img"
output_kernel="$output_dir/Image-v29-kexec-bridge"
output_ramdisk="$output_dir/initramfs-v29-kexec-bridge.cpio.gz"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

for input in "$kernel" "$kexec_binary" "$stock_recovery" "$v28_recovery"; do
	[[ -s $input ]] || { echo "Missing package input: $input" >&2; exit 1; }
done
[[ ! -e $output_image ]]
mkdir -p "$output_dir"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v28_recovery" --out "$stage/v28" --format info \
	>"$stage/v28-info.txt"

KEXEC_BINARY="$kexec_binary" \
	"$project_dir/scripts/inject-development-initramfs.sh" \
	"$stage/v28/ramdisk" "$output_ramdisk"
install -m0644 "$kernel" "$output_kernel"

"$project_dir/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$stock_recovery" \
	"$output_kernel" \
	"$output_ramdisk" \
	"$stage/v28/dtb" \
	"$output_image"

sha256sum "$output_kernel" "$output_ramdisk" "$output_image" "$kexec_binary"
