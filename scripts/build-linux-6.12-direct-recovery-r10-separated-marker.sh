#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r10-separated-marker
stage0=/mnt/d/TB371FC-builds/diagnostic-7.1.8-stage0-minimal-direct-text-offset-empty-dtbo-recovery-7.1.8.img
image=$output/recovery.img

test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }
mkdir -p "$output/stage0-unpack"
python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$stage0" \
	--out "$output/stage0-unpack" --format info >"$output/EMPTY-DTBO-SOURCE.txt"
test "$(stat -c %s "$output/stage0-unpack/recovery_dtbo")" = 359

export RECOVERY_DTBO=$output/stage0-unpack/recovery_dtbo
# Physical addresses are DRAM base 0x80000000 plus these Android offsets.
# Keep Image, initramfs and DTB disjoint in the free 0x92000000..0x9c000000 gap.
export KERNEL_OFFSET=0x12000000
export RAMDISK_OFFSET=0x14000000
export DTB_OFFSET=0x16000000
export DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 fbcon=font:TER16x32 keep_bootcon ignore_loglevel log_buf_len=8M rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 androidboot.serialno=0000000000 androidboot.slot_suffix=_b androidboot.verifiedbootstate=orange'

"$project/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py /root/mkbootimg/unpack_bootimg.py \
	/root/avb/avbtool.py \
	"$project/artifacts/device-backup/lun0-recovery_b.bin" \
	"$package/Image" "$package/initramfs-6.12-arch-development.cpio.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" "$image"

python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$image" \
	--out "$output/unpacked" --format info >"$output/UNPACK-INFO.txt"
python3 /root/avb/avbtool.py verify_image --image "$image"
grep -q '^kernel load address: 0x12000000$' "$output/UNPACK-INFO.txt"
grep -q '^ramdisk load address: 0x14000000$' "$output/UNPACK-INFO.txt"
grep -q '^dtb address: 0x0000000016000000$' "$output/UNPACK-INFO.txt"
cmp "$output/unpacked/kernel" "$package/Image"
cmp "$output/unpacked/ramdisk" "$package/initramfs-6.12-arch-development.cpio.gz"
cmp "$output/unpacked/dtb" "$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb"
cmp "$output/unpacked/recovery_dtbo" "$RECOVERY_DTBO"
sha256sum "$package/Image" "$package/initramfs-6.12-arch-development.cpio.gz" \
	"$package/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb" \
	"$RECOVERY_DTBO" "$image" >"$output/SHA256SUMS"
cat "$output/UNPACK-INFO.txt"
cat "$output/SHA256SUMS"
