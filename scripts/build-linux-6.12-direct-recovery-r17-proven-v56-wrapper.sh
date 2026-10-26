#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
package=${PACKAGE:-/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2}
v56=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe/tb371fc-arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe-recovery.img
output=${OUTPUT:-/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r17-proven-v56-wrapper}
build_label=${BUILD_LABEL:-'r17 proven V56 wrapper'}
extra_cflags=${EXTRA_CFLAGS:-}
cmdline_extra=${CMDLINE_EXTRA:-}
ramdisk_override=${RAMDISK_OVERRIDE:-}
dtb_override=${DTB_OVERRIDE:-}
image=$output/recovery.img
linux_base=${LINUX_BASE:-0xa0000000}
source_offset=4096
partition_size=$((100 * 1024 * 1024))
v56_sha=c08efccc1f94d0c3da9ce0689b668c4640cc27523e64c97e81bde767eef1ab3b

test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }
test "$(sha256sum "$v56" | awk '{print $1}')" = "$v56_sha"
mkdir -p "$output/v56-unpacked" "$output/unpacked"
python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$v56" \
	--out "$output/v56-unpacked" --format info >"$output/V56-UNPACK-INFO.txt"
grep -q '^boot image header version: 2$' "$output/V56-UNPACK-INFO.txt"
grep -q '^kernel load address: 0x00008000$' "$output/V56-UNPACK-INFO.txt"
grep -q '^recovery dtbo size: 4299995$' "$output/V56-UNPACK-INFO.txt"

ramdisk=${ramdisk_override:-$output/v56-unpacked/ramdisk}
dtb=${dtb_override:-$output/v56-unpacked/dtb}
test -s "$ramdisk"
test -s "$dtb"

wrapper_size=$(stat -c %s "$output/v56-unpacked/kernel")
image_size=$(stat -c %s "$package/Image")
copy_size=$(( (image_size + 15) & ~15 ))
(( source_offset + copy_size <= wrapper_size ))

aarch64-linux-gnu-gcc -c -x assembler-with-cpp -nostdlib -ffreestanding \
	$extra_cflags \
	-DWRAPPER_SIZE=$wrapper_size -DSOURCE_OFFSET=$source_offset \
	-DLINUX_BASE=$linux_base -DLINUX_COPY_SIZE=$copy_size \
	"$project/u-boot-port/abl-linux-direct-diagnostic-shim.S" \
	-o "$output/abl-linux-direct-diagnostic-shim.o"
aarch64-linux-gnu-ld -nostdlib -static \
	-T "$project/u-boot-port/abl-entry-probe.lds" \
	-o "$output/abl-linux-direct-diagnostic-shim.elf" \
	"$output/abl-linux-direct-diagnostic-shim.o"
aarch64-linux-gnu-objcopy -O binary "$output/abl-linux-direct-diagnostic-shim.elf" \
	"$output/abl-linux-direct-diagnostic-shim.bin"
shim_size=$(stat -c %s "$output/abl-linux-direct-diagnostic-shim.bin")
(( shim_size <= source_offset ))
truncate -s "$source_offset" "$output/abl-linux-direct-diagnostic-shim.bin"
cat "$output/abl-linux-direct-diagnostic-shim.bin" "$package/Image" \
	>"$output/kernel-wrapper.bin"
truncate -s "$wrapper_size" "$output/kernel-wrapper.bin"

cmdline="earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 androidboot.serialno=0000000000 androidboot.slot_suffix=_b androidboot.verifiedbootstate=orange${cmdline_extra:+ $cmdline_extra}"
python3 /root/mkbootimg/mkbootimg.py \
	--header_version 2 --pagesize 4096 --base 0 \
	--kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
	--tags_offset 0x00000100 --dtb_offset 0x01f00000 \
	--os_version 11.0.0 --os_patch_level 2024-02 \
	--cmdline "$cmdline" \
	--kernel "$output/kernel-wrapper.bin" \
	--ramdisk "$ramdisk" \
	--recovery_dtbo "$output/v56-unpacked/recovery_dtbo" \
	--dtb "$dtb" \
	--output "$image"

python3 /root/avb/avbtool.py add_hash_footer \
	--image "$image" --partition_size "$partition_size" \
	--partition_name recovery --algorithm NONE --hash_algorithm sha256 \
	--salt 55e325516e7ae7202f867f2b02712affc4677aff76b16857e3d7875c403ef1e5 \
	--prop 'com.android.build.recovery.fingerprint:Lenovo/TB371FC_PRC/TB371FC:14/UKQ1.231222.001/ZUI_16.0.474_241129_PRC:user/release-keys'

test "$(stat -c %s "$image")" = "$partition_size"
python3 /root/avb/avbtool.py verify_image --image "$image"
python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$image" \
	--out "$output/unpacked" --format info >"$output/UNPACK-INFO.txt"
cmp "$output/unpacked/kernel" "$output/kernel-wrapper.bin"
cmp "$output/unpacked/ramdisk" "$ramdisk"
cmp "$output/unpacked/recovery_dtbo" "$output/v56-unpacked/recovery_dtbo"
cmp "$output/unpacked/dtb" "$dtb"
dd if="$output/unpacked/kernel" of="$output/extracted-Image" \
	iflag=skip_bytes,count_bytes skip="$source_offset" count="$image_size" \
	bs=4M status=none
cmp "$output/extracted-Image" "$package/Image"

aarch64-linux-gnu-objdump -d "$output/abl-linux-direct-diagnostic-shim.elf" \
	>"$output/SHIM-DISASSEMBLY.txt"
{
	echo "TB371FC Linux 6.12 direct recovery $build_label"
	echo "V56 kernel wrapper bytes preserved: $wrapper_size"
	echo "Linux source offset: 0x$(printf '%x' "$source_offset")"
	echo "Linux destination: $linux_base"
	echo "Image bytes: $image_size; copy bytes: $copy_size"
	echo 'Stages: red=entry green=copy blue=cache white=MMU-off magenta=MMU-on'
	sha256sum "$package/Image" "$output/kernel-wrapper.bin" \
		"$ramdisk" "$output/v56-unpacked/recovery_dtbo" \
		"$dtb" "$image"
} >"$output/BUILD-INFO.txt"

cat "$output/UNPACK-INFO.txt"
cat "$output/BUILD-INFO.txt"
