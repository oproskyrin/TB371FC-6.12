#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
set -euo pipefail

if (( $# != 8 )); then
	echo "Usage: $0 MKBOOTIMG_PY UNPACK_BOOTIMG_PY AVBTOOL_PY STOCK_RECOVERY IMAGE INITRAMFS DTB OUTPUT_RECOVERY" >&2
	exit 2
fi

mkbootimg=$(realpath "$1")
unpack_bootimg=$(realpath "$2")
avbtool=$(realpath "$3")
stock_recovery=$(realpath "$4")
kernel=$(realpath "$5")
ramdisk=$(realpath "$6")
dtb=$(realpath "$7")
output=$(realpath -m "$8")
[[ ! -e $output ]] || {
	echo "Refusing to overwrite existing recovery image: $output" >&2
	exit 1
}
# Fail before creating a partial output if an obsolete Python-2 avbtool was
# selected accidentally.
python3 "$avbtool" version >/dev/null
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

expected_stock_sha256=94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668
actual_stock_sha256=$(sha256sum "$stock_recovery" | awk '{print $1}')
if [[ $actual_stock_sha256 != "$expected_stock_sha256" ]]; then
	echo "Stock recovery SHA-256 mismatch: $actual_stock_sha256" >&2
	exit 1
fi

python3 "$unpack_bootimg" --boot_img "$stock_recovery" --out "$stage" --format info >"$stage/stock-info.txt"
grep -q '^boot image header version: 2$' "$stage/stock-info.txt"
grep -q '^page size: 4096$' "$stage/stock-info.txt"
grep -q '^recovery dtbo size: 4299963$' "$stage/stock-info.txt"

if [[ -n ${RECOVERY_DTBO:-} ]]; then
	recovery_dtbo=$(realpath "$RECOVERY_DTBO")
else
	recovery_dtbo="$stage/recovery_dtbo"
fi

mkdir -p "$(dirname "$output")"
cmdline=${DIAGNOSTIC_CMDLINE:-'earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:SUN12x22 keep_bootcon ignore_loglevel initcall_debug rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused panic=-1 swiotlb=2048'}
kernel_offset=${KERNEL_OFFSET:-0x00008000}
ramdisk_offset=${RAMDISK_OFFSET:-0x01000000}
dtb_offset=${DTB_OFFSET:-0x01f00000}

python3 "$mkbootimg" \
	--header_version 2 \
	--pagesize 4096 \
	--base 0x00000000 \
	--kernel_offset "$kernel_offset" \
	--ramdisk_offset "$ramdisk_offset" \
	--tags_offset 0x00000100 \
	--dtb_offset "$dtb_offset" \
	--os_version 11.0.0 \
	--os_patch_level 2024-02 \
	--cmdline "$cmdline" \
	--kernel "$kernel" \
	--ramdisk "$ramdisk" \
	--recovery_dtbo "$recovery_dtbo" \
	--dtb "$dtb" \
	--output "$output"

max_size=$((100 * 1024 * 1024))
python3 "$avbtool" add_hash_footer \
	--image "$output" \
	--partition_size "$max_size" \
	--partition_name recovery \
	--algorithm NONE \
	--hash_algorithm sha256 \
	--salt 55e325516e7ae7202f867f2b02712affc4677aff76b16857e3d7875c403ef1e5 \
	--prop 'com.android.build.recovery.fingerprint:Lenovo/TB371FC_PRC/TB371FC:14/UKQ1.231222.001/ZUI_16.0.474_241129_PRC:user/release-keys'

actual_size=$(stat -c %s "$output")
if (( actual_size != max_size )); then
	echo "AVB recovery image does not fill recovery_b: $actual_size != $max_size" >&2
	exit 1
fi

echo "Diagnostic Android recovery v2 image: $output"
printf 'Size: %d bytes (limit: %d)\n' "$actual_size" "$max_size"
sha256sum "$output"
sha256sum "$recovery_dtbo"
