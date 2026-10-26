#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
v565=/mnt/d/TB371FC-builds/arch-development-loader-v56-5-r2-community-simplefb-qca6390-kde-kexec-cpu-hotplug-safe
source_ramdisk=$v565/tb371fc-v56-5-r2-simplefb-qca6390-kde-kexec-cpu-hotplug-safe.cpio.gz
kernel=$v565/Image-v56-5
dtb=$v565/dtb-v56-5.img
recovery_dtbo=$v565/recovery-dtbo-v56-5.img
stock="$project/artifacts/device-backup/lun0-recovery_b.bin"
linux612=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r37-head-stage-diagnostic/Image
diag39='/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-diag39+-safe-diag39-r2'
linux612_dtb=$diag39/dtb/qcom/sm8250-lenovo-tb371fc-archsafe-microsd.dtb
linux612_initrd=$diag39/initramfs-6.12-arch-development.cpio.gz
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-v56.5-controlled-kexec-r37
ramdisk=$output/tb371fc-v56.5-controlled-linux-6.12-r37.cpio.gz
recovery=$output/tb371fc-v56.5-controlled-linux-6.12-r37-recovery.img

for f in "$source_ramdisk" "$kernel" "$dtb" "$recovery_dtbo" "$stock" \
	"$linux612" "$linux612_dtb" "$linux612_initrd" \
	"$project/initramfs/init-v56-5-controlled-linux-6.12-r37" \
	"$project/initramfs/load-linux-6.12-r37" \
	"$project/initramfs/execute-linux-6.12-r37" \
	"$project/initramfs/status-linux-6.12-r37"; do
	test -s "$f"
done

printf '%s  %s\n' 8d18f740d2821a2dd214714ca9c5296c58b2b3a71e45bf619b4002cbac04757f "$linux612" | sha256sum -c -
printf '%s  %s\n' caa9598e88b9b4a39d39916651d306824e2f44d8325822e510bcb6d0cede357c "$linux612_dtb" | sha256sum -c -
printf '%s  %s\n' c807299d26b83c2d585a1ae8402dfbb68852a647ed153bf190123e9a7048dd9c "$linux612_initrd" | sha256sum -c -

mkdir -p "$output"
rm -f "$ramdisk" "$recovery"
stage=$(mktemp -d)
unpacked=$(mktemp -d)
trap 'rm -rf -- "$stage" "$unpacked"' EXIT

( cd "$stage"; gzip -dc "$source_ramdisk" | cpio -idmu 2>/dev/null )
test -x "$stage/bin/kexec"
install -m0755 "$project/initramfs/init-v56-5-controlled-linux-6.12-r37" "$stage/init"
install -m0755 "$project/initramfs/load-linux-6.12-r37" "$stage/bin/load-linux-6.12-r37"
install -m0755 "$project/initramfs/execute-linux-6.12-r37" "$stage/bin/execute-linux-6.12-r37"
install -m0755 "$project/initramfs/status-linux-6.12-r37" "$stage/bin/status-linux-6.12-r37"
install -d -m0755 "$stage/opt/tb371fc-linux-6.12-r37"
install -m0644 "$linux612" "$stage/opt/tb371fc-linux-6.12-r37/Image"
install -m0644 "$linux612_dtb" "$stage/opt/tb371fc-linux-6.12-r37/board.dtb"
install -m0644 "$linux612_initrd" "$stage/opt/tb371fc-linux-6.12-r37/initramfs.cpio.gz"
for script in "$stage/init" "$stage/bin/load-linux-6.12-r37" \
	"$stage/bin/execute-linux-6.12-r37" "$stage/bin/status-linux-6.12-r37"; do
	sh -n "$script"
done

( cd "$stage"; find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 2>/dev/null | gzip -9n >"$ramdisk" )

RECOVERY_DTBO="$recovery_dtbo" \
DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 msm_drm.sdecustom=0 video=Virtual-1:d fbcon=font:SUN12x22 fbcon=nodefer' \
	bash "$project/scripts/build-diagnostic-recovery.sh" \
	/root/mkbootimg/mkbootimg.py /root/mkbootimg/unpack_bootimg.py /root/avb/avbtool.py \
	"$stock" "$kernel" "$ramdisk" "$dtb" "$recovery"

python3 /root/mkbootimg/unpack_bootimg.py --boot_img "$recovery" --out "$unpacked" --format=info >"$output/unpack-info.txt"
cmp "$unpacked/kernel" "$kernel"
cmp "$unpacked/ramdisk" "$ramdisk"
cmp "$unpacked/dtb" "$dtb"
cmp "$unpacked/recovery_dtbo" "$recovery_dtbo"

cat >"$output/BUILD-INFO.txt" <<EOF
TB371FC r37 controlled two-stage recovery
Default: proven V56.5 Linux 4.19, USB ACM, Arch/KDE and SSH.
Linux 6.12: corrected kexec load call and safe full-screen head.S stage markers.
Status:  /run/tb371fc-rescue/status-linux-6.12-r37
Load:    /run/tb371fc-rescue/load-linux-6.12-r37
Execute: /run/tb371fc-rescue/execute-linux-6.12-r37
Temporary test touches only recovery_b and verification-disabled vbmeta_b.
EOF
( cd "$output"; sha256sum "$(basename "$ramdisk")" "$(basename "$recovery")" BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'ramdisk=%s recovery=%s' "$ramdisk" "$recovery"
