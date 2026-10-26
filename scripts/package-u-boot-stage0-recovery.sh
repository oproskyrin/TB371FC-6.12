#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${UBOOT_ARTIFACT_DIR:-/mnt/d/TB371FC-builds/u-boot-tb371fc-stage0}
stock_recovery=${STOCK_RECOVERY:-$project_dir/artifacts/device-backup/lun0-recovery_b.bin}
mkbootimg=${MKBOOTIMG:-/root/mkbootimg/mkbootimg.py}
unpack_bootimg=${UNPACK_BOOTIMG:-/root/mkbootimg/unpack_bootimg.py}
avbtool=${AVBTOOL:-/root/avb/avbtool.py}
# Lenovo ABL boots the stock and the physically proven V55 recovery with an
# uncompressed ARM64 Image in the kernel field.  Early hardware tests showed
# that a gzip-compressed U-Boot image returns directly to Lenovo fastboot, so
# keep the stage-0 payload in the same uncompressed format as those baselines.
kernel="$artifact_dir/u-boot-nodtb.bin"
dtb="$artifact_dir/sm8250-lenovo-tb371fc-u-boot.dtb"
output="$artifact_dir/tb371fc-u-boot-stage0-recovery.img"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

for input in "$stock_recovery" "$mkbootimg" "$unpack_bootimg" "$avbtool" "$kernel" "$dtb"; do
	[[ -s $input ]] || { echo "Missing package input: $input" >&2; exit 1; }
done
[[ ! -e $output ]] || { echo "Refusing to overwrite: $output" >&2; exit 1; }

expected_stock_sha256=94649360140db672e861729927011984e9714459b4e19c9aab02b7ab79466668
actual_stock_sha256=$(sha256sum "$stock_recovery" | awk '{print $1}')
[[ $actual_stock_sha256 == "$expected_stock_sha256" ]] || {
	echo "Stock recovery SHA-256 mismatch: $actual_stock_sha256" >&2
	exit 1
}

python3 "$unpack_bootimg" --boot_img "$stock_recovery" --out "$stage/stock" --format info \
	>"$stage/stock-info.txt"
grep -q '^boot image header version: 2$' "$stage/stock-info.txt"
grep -q '^page size: 4096$' "$stage/stock-info.txt"
grep -q '^recovery dtbo size: 4299963$' "$stage/stock-info.txt"

# Preserve Lenovo's recovery DTBO field so ABL sees the same recovery layout.
# The U-Boot config itself contains no UFS or flash-writing backend.
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
	--cmdline '' \
	--kernel "$kernel" \
	--ramdisk /dev/null \
	--recovery_dtbo "$stage/stock/recovery_dtbo" \
	--dtb "$dtb" \
	--output "$output"

partition_size=$((100 * 1024 * 1024))
python3 "$avbtool" add_hash_footer \
	--image "$output" \
	--partition_size "$partition_size" \
	--partition_name recovery \
	--algorithm NONE \
	--hash_algorithm sha256 \
	--salt 55e325516e7ae7202f867f2b02712affc4677aff76b16857e3d7875c403ef1e5 \
	--prop 'com.android.build.recovery.fingerprint:Lenovo/TB371FC_PRC/TB371FC:14/UKQ1.231222.001/ZUI_16.0.474_241129_PRC:user/release-keys'

[[ $(stat -c %s "$output") -eq $partition_size ]]
sha256sum "$output" >"$artifact_dir/RECOVERY-SHA256SUMS"
printf '%s\n' 'Hardware status: OFFLINE ONLY; NOT FLASHED' \
	>"$artifact_dir/RECOVERY-STATUS.txt"

sha256sum "$output"
