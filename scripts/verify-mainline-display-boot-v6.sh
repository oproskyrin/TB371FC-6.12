#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_dir=${SOURCE_DIR:-/mnt/d/TB371FC-builds/mainline-7.1.7-native-display-phycfg-v4}
package_dir=${PACKAGE_DIR:-/mnt/d/TB371FC-builds/mainline-7.1.7-native-display-phycfg-boot-v6}
boot="$package_dir/tb371fc-mainline-7.1.7-native-display-phycfg-v6-boot.img"
kernel="$package_dir/Image-7.1.7-tb371fc-native-display-phycfg-v6-text80000"
ramdisk="$package_dir/tb371fc-mainline-display-initramfs-v6.cpio.gz"
dtb="$source_dir/sm8250-lenovo-tb371fc-display-test.dtb"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

info=$(python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$boot" --out "$stage" --format info)
printf '%s\n' "$info"
grep -q '^boot magic: ANDROID!$' <<<"$info"
grep -q '^boot image header version: 2$' <<<"$info"
grep -q '^page size: 4096$' <<<"$info"
grep -q '^kernel load address: 0x00008000$' <<<"$info"
grep -q '^ramdisk load address: 0x01000000$' <<<"$info"
grep -q '^kernel tags load address: 0x00000100$' <<<"$info"
grep -q '^recovery dtbo size: 0$' <<<"$info"
grep -q '^dtb address: 0x0000000001f00000$' <<<"$info"
cmp "$kernel" "$stage/kernel"
cmp "$ramdisk" "$stage/ramdisk"
cmp "$dtb" "$stage/dtb"

mkdir "$stage/initramfs"
(
	cd "$stage/initramfs"
	gzip -dc "$ramdisk" | cpio -id --quiet
)
file "$stage/initramfs/bin/reboot-bootloader" | grep -q 'ARM aarch64.*statically linked'
strings "$stage/initramfs/bin/reboot-bootloader" | \
	grep -x 'LOGS_COPIED_REBOOT_TO_BOOTLOADER' >/dev/null

cp "$boot" "$stage/boot.img"
python3 /root/avb/avbtool.py verify_image --image "$stage/boot.img"
avb_info=$(python3 /root/avb/avbtool.py info_image --image "$boot")
grep -q 'Partition Name:        boot' <<<"$avb_info"
grep -q 'Algorithm:                NONE' <<<"$avb_info"
test "$(stat -c %s "$boot")" -eq $((96 * 1024 * 1024))

# ARM64 Image header: text_offset at byte 8 and magic at byte 56.
test "$(od -An -tx8 -j8 -N8 "$kernel" | tr -d ' ')" = 0000000000080000
test "$(dd if="$kernel" bs=1 skip=56 count=4 status=none)" = ARMd

python3 "$project_dir/scripts/verify-mainline-dsc-pps.py"
python3 "$project_dir/scripts/verify-mainline-tianma-command-table.py"
python3 "$project_dir/scripts/verify-mainline-display-timing.py"
grep -Eq '^\+[[:space:]]*\.slice_count = 2,' \
	"$project_dir/mainline-port/patches/0001-drm-panel-nt36523-add-lenovo-tb371fc-nt36532.patch"

echo 'Verified v6 stock-layout boot image, AVB footer, embedded v4 payloads and safe bootloader return helper.'
sha256sum "$kernel" "$ramdisk" "$dtb" "$boot"
