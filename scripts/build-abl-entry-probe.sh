#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
v55=${V55_RECOVERY:-/mnt/d/TB371FC-builds/arch-development-loader-v55-community-simplefb-arch-loopback-ssh/tb371fc-arch-development-loader-v55-community-simplefb-arch-loopback-ssh-recovery.img}
output_dir=${OUTPUT_DIR:-/mnt/d/TB371FC-builds/abl-entry-probe-v1}
mkbootimg=${MKBOOTIMG:-/root/mkbootimg/mkbootimg.py}
unpack_bootimg=${UNPACK_BOOTIMG:-/root/mkbootimg/unpack_bootimg.py}
avbtool=${AVBTOOL:-/root/avb/avbtool.py}
source="$project_dir/u-boot-port/abl-entry-probe.S"
linker="$project_dir/u-boot-port/abl-entry-probe.lds"
output="$output_dir/tb371fc-abl-entry-probe-v1-recovery.img"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

for input in "$v55" "$mkbootimg" "$unpack_bootimg" "$avbtool" "$source" "$linker"; do
	[[ -s $input ]] || { echo "Missing input: $input" >&2; exit 1; }
done
[[ $(sha256sum "$v55" | awk '{print $1}') == c03331d9f85e33c490c6bfe8892d6b118b5283680c18729e9897d69228a4e9e5 ]]
[[ ! -e $output_dir ]] || { echo "Refusing to overwrite: $output_dir" >&2; exit 1; }
mkdir -p "$output_dir"

aarch64-linux-gnu-gcc -c -x assembler-with-cpp -nostdlib -ffreestanding \
	-o "$stage/abl-entry-probe.o" "$source"
aarch64-linux-gnu-ld -nostdlib -static -T "$linker" \
	-o "$stage/abl-entry-probe.elf" "$stage/abl-entry-probe.o"
aarch64-linux-gnu-objcopy -O binary --gap-fill 0 \
	--pad-to 0x80081000 \
	"$stage/abl-entry-probe.elf" "$output_dir/abl-entry-probe.bin"

python3 "$unpack_bootimg" --boot_img "$v55" --out "$stage/v55" --format info \
	>"$output_dir/v55-unpack-info.txt"
grep -q '^boot image header version: 2$' "$output_dir/v55-unpack-info.txt"
grep -q '^page size: 4096$' "$output_dir/v55-unpack-info.txt"
grep -q '^recovery dtbo size: 4299995$' "$output_dir/v55-unpack-info.txt"

cmdline='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 msm_drm.sdecustom=0 video=Virtual-1:d fbcon=font:SUN12x22 fbcon=nodefer'
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
	--kernel "$output_dir/abl-entry-probe.bin" \
	--ramdisk "$stage/v55/ramdisk" \
	--recovery_dtbo "$stage/v55/recovery_dtbo" \
	--dtb "$stage/v55/dtb" \
	--output "$output"

python3 "$avbtool" add_hash_footer \
	--image "$output" \
	--partition_size $((100 * 1024 * 1024)) \
	--partition_name recovery \
	--algorithm NONE \
	--hash_algorithm sha256 \
	--salt 55e325516e7ae7202f867f2b02712affc4677aff76b16857e3d7875c403ef1e5 \
	--prop 'com.android.build.recovery.fingerprint:Lenovo/TB371FC_PRC/TB371FC:14/UKQ1.231222.001/ZUI_16.0.474_241129_PRC:user/release-keys'

python3 "$unpack_bootimg" --boot_img "$output" --out "$stage/probe" --format info \
	>"$output_dir/probe-unpack-info.txt"
cmp "$stage/probe/kernel" "$output_dir/abl-entry-probe.bin"
cmp "$stage/probe/ramdisk" "$stage/v55/ramdisk"
cmp "$stage/probe/recovery_dtbo" "$stage/v55/recovery_dtbo"
cmp "$stage/probe/dtb" "$stage/v55/dtb"
[[ $(stat -c %s "$output") -eq $((100 * 1024 * 1024)) ]]

cat >"$output_dir/TEST-INSTRUCTIONS.txt" <<'EOF'
Expected result if Qualcomm ABL enters the payload:
  full-screen 64x64 opaque green/magenta checkerboard that remains static.

No USB gadget, shell, storage driver, reboot call, DT parser, or U-Boot code is
present. A return to Lenovo fastboot without the checkerboard means the failure
is before the payload entry. The test writes only recovery_b and vbmeta_b via
the existing attended rollback controller.
EOF
printf '%s\n' 'Hardware status: OFFLINE ONLY; NOT FLASHED' >"$output_dir/HARDWARE-STATUS.txt"
sha256sum "$output_dir/abl-entry-probe.bin" "$output" >"$output_dir/SHA256SUMS"
cat "$output_dir/SHA256SUMS"
