#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r15-lenovo-q706f-layout
image=$output/recovery.img
partition_size=$((100 * 1024 * 1024))

test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }
mkdir -p "$output/unpacked"

# Lenovo Q706F's postmarketOS port uses the zinstall output (Image.gz),
# appends the board DTB to that file, and places the result in a legacy
# Android boot image without a separate v2 DTB field.
gzip -n -9 -c "$package/Image" >"$output/Image.gz"
cat "$output/Image.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
	>"$output/Image.gz-dtb"

cmdline='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 androidboot.serialno=0000000000 androidboot.slot_suffix=_b androidboot.verifiedbootstate=orange'

python3 /root/mkbootimg/mkbootimg.py \
	--header_version 0 \
	--pagesize 4096 \
	--base 0 \
	--kernel_offset 0x00008000 \
	--ramdisk_offset 0x01000000 \
	--second_offset 0x00f00000 \
	--tags_offset 0x00000100 \
	--os_version 11.0.0 \
	--os_patch_level 2024-02 \
	--cmdline "$cmdline" \
	--kernel "$output/Image.gz-dtb" \
	--ramdisk "$package/initramfs-6.12-arch-development.cpio.gz" \
	--output "$image"

python3 /root/avb/avbtool.py add_hash_footer \
	--image "$image" \
	--partition_size "$partition_size" \
	--partition_name recovery \
	--algorithm NONE \
	--hash_algorithm sha256 \
	--salt 55e325516e7ae7202f867f2b02712affc4677aff76b16857e3d7875c403ef1e5 \
	--prop 'com.android.build.recovery.fingerprint:Lenovo/TB371FC_PRC/TB371FC:14/UKQ1.231222.001/ZUI_16.0.474_241129_PRC:user/release-keys'

test "$(stat -c %s "$image")" = "$partition_size"
python3 /root/avb/avbtool.py verify_image --image "$image"
python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$image" \
	--out "$output/unpacked" --format info >"$output/UNPACK-INFO.txt"
grep -q '^boot image header version: 0$' "$output/UNPACK-INFO.txt"
grep -q '^kernel load address: 0x00008000$' "$output/UNPACK-INFO.txt"
grep -q '^ramdisk load address: 0x01000000$' "$output/UNPACK-INFO.txt"
cmp "$output/unpacked/kernel" "$output/Image.gz-dtb"
cmp "$output/unpacked/ramdisk" "$package/initramfs-6.12-arch-development.cpio.gz"

gzip_size=$(stat -c %s "$output/Image.gz")
head -c "$gzip_size" "$output/unpacked/kernel" | gzip -dc | cmp - "$package/Image"
tail -c +$((gzip_size + 1)) "$output/unpacked/kernel" | \
	cmp - "$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"

{
	echo 'TB371FC Linux 6.12 direct recovery r15 (Lenovo Q706F layout)'
	echo 'Layout: Image.gz + appended DTB'
	echo 'Android boot header: v0'
	echo 'Offsets: kernel=0x8000 ramdisk=0x01000000 second=0x00f00000 tags=0x100'
	sha256sum "$package/Image" "$output/Image.gz" \
		"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
		"$package/initramfs-6.12-arch-development.cpio.gz" "$image"
} >"$output/BUILD-INFO.txt"

cat "$output/UNPACK-INFO.txt"
cat "$output/BUILD-INFO.txt"
