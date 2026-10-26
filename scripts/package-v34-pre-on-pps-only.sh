#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kernel=/root/tb371fc-lenovo-4.19-v34-pre-on-pps-only-out/arch/arm64/boot/Image
kexec_binary=/root/kexec-tools-build-aarch64/build/sbin/kexec
stock_recovery="$project_dir/artifacts/device-backup/lun0-recovery_b.bin"
v32_recovery=/mnt/d/TB371FC-builds/arch-development-loader-v32-nt36532-vendor-dsc/tb371fc-arch-development-loader-v32-nt36532-vendor-dsc-recovery.img
output_dir=/mnt/d/TB371FC-builds/arch-development-loader-v34-pre-on-pps-only
output_image="$output_dir/tb371fc-arch-development-loader-v34-pre-on-pps-only-recovery.img"
output_kernel="$output_dir/Image-v34-pre-on-pps-only"
output_ramdisk="$output_dir/initramfs-v34-pre-on-pps-only-kexec.cpio.gz"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

[[ -s $kernel ]]
[[ -s $kexec_binary ]]
[[ -s $stock_recovery ]]
[[ -s $v32_recovery ]]
[[ ! -e $output_image ]]
mkdir -p "$output_dir"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$v32_recovery" --out "$stage/v32" --format info \
	>"$stage/v32-info.txt"

install -m 0644 "$kernel" "$output_kernel"
KEXEC_BINARY="$kexec_binary" \
	"$project_dir/scripts/inject-development-initramfs.sh" \
	"$stage/v32/ramdisk" "$output_ramdisk"
"$project_dir/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$stock_recovery" \
	"$output_kernel" \
	"$output_ramdisk" \
	"$stage/v32/dtb" \
	"$output_image"

sha256sum "$output_kernel" "$output_ramdisk" "$stage/v32/dtb" "$output_image" "$kexec_binary"
