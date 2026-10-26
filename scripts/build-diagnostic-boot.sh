#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
set -euo pipefail

if (( $# != 5 )); then
	echo "Usage: $0 MKBOOTIMG_PY IMAGE INITRAMFS DTB OUTPUT_BOOT_IMG" >&2
	exit 2
fi

mkbootimg=$(realpath "$1")
kernel=$(realpath "$2")
ramdisk=$(realpath "$3")
dtb=$(realpath "$4")
output=$(realpath -m "$5")
[[ ! -e $output ]] || {
	echo "Refusing to overwrite existing boot image: $output" >&2
	exit 1
}
mkdir -p "$(dirname "$output")"

cmdline=${DIAGNOSTIC_CMDLINE:-'earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:SUN12x22 keep_bootcon ignore_loglevel initcall_debug rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused panic=-1 swiotlb=2048'}

python3 "$mkbootimg" \
	--header_version 2 \
	--pagesize 4096 \
	--base 0x00000000 \
	--kernel_offset 0x00008000 \
	--ramdisk_offset 0x01000000 \
	--tags_offset 0x00000100 \
	--dtb_offset 0x01f00000 \
	--os_version 11.0.0 \
	--os_patch_level 2024-02 \
	--cmdline "$cmdline" \
	--kernel "$kernel" \
	--ramdisk "$ramdisk" \
	--dtb "$dtb" \
	--output "$output"

max_size=$((96 * 1024 * 1024))
actual_size=$(stat -c %s "$output")
if (( actual_size > max_size )); then
	echo "Boot image is larger than the stock 96 MiB partition: $actual_size" >&2
	exit 1
fi

if [[ $(dd if="$output" bs=8 count=1 status=none) != ANDROID! ]]; then
	echo "Generated file does not have Android boot magic" >&2
	exit 1
fi

echo "Diagnostic Android boot v2 image: $output"
printf 'Size: %d bytes (limit: %d)\n' "$actual_size" "$max_size"
sha256sum "$output"
