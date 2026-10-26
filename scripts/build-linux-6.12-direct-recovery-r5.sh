#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-desktop+-desktop-r4
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r5
image=$output/recovery.img

test ! -e "$output" || {
	echo "Refusing to overwrite $output" >&2
	exit 1
}
mkdir -p "$output"

export DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 androidboot.serialno=0000000000 androidboot.slot_suffix=_b androidboot.verifiedbootstate=orange'

"$project/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py \
	/root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$project/artifacts/device-backup/lun0-recovery_b.bin" \
	"$package/Image" \
	"$package/initramfs-6.12-arch-development.cpio.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
	"$image"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$image" --out "$output/unpacked" --format info \
	>"$output/UNPACK-INFO.txt"
python3 /root/avb/avbtool.py verify_image --image "$image"
cmp "$output/unpacked/kernel" "$package/Image"
cmp "$output/unpacked/ramdisk" \
	"$package/initramfs-6.12-arch-development.cpio.gz"
cmp "$output/unpacked/dtb" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
sha256sum "$image" >"$output/SHA256SUMS"

cat "$output/UNPACK-INFO.txt"
cat "$output/SHA256SUMS"
