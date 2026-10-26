#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r13-image-gz
stage0=/mnt/d/TB371FC-builds/diagnostic-7.1.8-stage0-minimal-direct-text-offset-empty-dtbo-recovery-7.1.8.img
kernel=$output/Image.gz
image=$output/recovery.img

test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }
mkdir -p "$output/stage0-unpack"
gzip -n -9 -c "$package/Image" >"$kernel"
gzip -t "$kernel"

python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$stage0" \
	--out "$output/stage0-unpack" --format info >"$output/EMPTY-DTBO-SOURCE.txt"
test "$(stat -c %s "$output/stage0-unpack/recovery_dtbo")" = 359
export RECOVERY_DTBO=$output/stage0-unpack/recovery_dtbo
export KERNEL_OFFSET=0x00008000
export RAMDISK_OFFSET=0x01000000
export DTB_OFFSET=0x01f00000
export DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 androidboot.serialno=0000000000 androidboot.slot_suffix=_b androidboot.verifiedbootstate=orange'

"$project/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py /root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$project/artifacts/device-backup/lun0-recovery_b.bin" \
	"$kernel" "$package/initramfs-6.12-arch-development.cpio.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" "$image"

python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$image" \
	--out "$output/unpacked" --format info >"$output/UNPACK-INFO.txt"
python3 /root/avb/avbtool.py verify_image --image "$image"
cmp "$output/unpacked/kernel" "$kernel"
cmp "$output/unpacked/ramdisk" "$package/initramfs-6.12-arch-development.cpio.gz"
cmp "$output/unpacked/dtb" "$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
cmp "$output/unpacked/recovery_dtbo" "$RECOVERY_DTBO"
gzip -dc "$output/unpacked/kernel" | cmp - "$package/Image"
sha256sum "$package/Image" "$kernel" "$package/initramfs-6.12-arch-development.cpio.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
	"$RECOVERY_DTBO" "$image" >"$output/SHA256SUMS"
cat "$output/UNPACK-INFO.txt"
cat "$output/SHA256SUMS"
