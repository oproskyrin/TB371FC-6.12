#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r14-mu-layout
stock="$project/artifacts/device-backup/lun0-recovery_b.bin"
image=$output/recovery.img
linux_base=0xa0000000
partition_size=$((100 * 1024 * 1024))

test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }
mkdir -p "$output/unpacked"

image_size=$(stat -c %s "$package/Image")
copy_size=$(( (image_size + 15) & ~15 ))

aarch64-linux-gnu-gcc -c -nostdlib -ffreestanding \
	-DLINUX_BASE=$linux_base -DLINUX_COPY_SIZE=$copy_size \
	"$project/u-boot-port/mu-linux-bootshim.S" -o "$output/mu-linux-bootshim.o"
aarch64-linux-gnu-ld -T "$project/u-boot-port/mu-linux-bootshim.lds" \
	-o "$output/mu-linux-bootshim.elf" "$output/mu-linux-bootshim.o"
aarch64-linux-gnu-objcopy -O binary \
	"$output/mu-linux-bootshim.elf" "$output/mu-linux-bootshim.bin"

cp "$package/Image" "$output/Image.padded"
truncate -s "$copy_size" "$output/Image.padded"
cat "$output/mu-linux-bootshim.bin" "$output/Image.padded" >"$output/linux-wrapper.bin"
gzip -n -9 -c "$output/linux-wrapper.bin" >"$output/linux-wrapper.bin.gz"
cat "$output/linux-wrapper.bin.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
	>"$output/kernel-with-appended-dtb.bin"

cmdline='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 androidboot.serialno=0000000000 androidboot.slot_suffix=_b androidboot.verifiedbootstate=orange'

python3 /root/mkbootimg/mkbootimg.py \
	--header_version 1 \
	--pagesize 4096 \
	--base 0 \
	--kernel_offset 0 \
	--ramdisk_offset 0 \
	--tags_offset 0 \
	--os_version 11.0.0 \
	--os_patch_level 2024-02 \
	--cmdline "$cmdline" \
	--kernel "$output/kernel-with-appended-dtb.bin" \
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
grep -q '^boot image header version: 1$' "$output/UNPACK-INFO.txt"
cmp "$output/unpacked/kernel" "$output/kernel-with-appended-dtb.bin"
cmp "$output/unpacked/ramdisk" "$package/initramfs-6.12-arch-development.cpio.gz"

gzip_size=$(stat -c %s "$output/linux-wrapper.bin.gz")
head -c "$gzip_size" "$output/unpacked/kernel" | gzip -dc | cmp - "$output/linux-wrapper.bin"
tail -c +$((gzip_size + 1)) "$output/unpacked/kernel" | \
	cmp - "$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"

shim_size=$(stat -c %s "$output/mu-linux-bootshim.bin")
payload_hex=$(aarch64-linux-gnu-nm -n "$output/mu-linux-bootshim.elf" | \
	awk '$3 == "_Payload" { print $1 }')
payload_symbol=$((16#$payload_hex))
test "$payload_symbol" = "$shim_size"
dd if="$output/linux-wrapper.bin" of="$output/extracted-Image.padded" \
	iflag=skip_bytes skip="$shim_size" bs=4M status=none
cmp "$output/extracted-Image.padded" "$output/Image.padded"

{
	echo "TB371FC Linux 6.12 direct recovery r14 (Mu-Qcom layout)"
	echo "Linux destination: $linux_base"
	echo "Raw Image bytes: $image_size"
	echo "Copy bytes (16-byte aligned): $copy_size"
	echo "Shim bytes: $shim_size"
	echo "Layout: gzip(shim + padded Image) + appended DTB"
	echo "Android boot header: v1; kernel/ramdisk/tags offsets: zero"
	sha256sum "$package/Image" "$output/mu-linux-bootshim.bin" \
		"$output/linux-wrapper.bin.gz" \
		"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
		"$package/initramfs-6.12-arch-development.cpio.gz" "$image"
} >"$output/BUILD-INFO.txt"

cat "$output/UNPACK-INFO.txt"
cat "$output/BUILD-INFO.txt"
