#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
COMMUNITY_KERNEL=/root/tb371fc-desktop-working-out-v49/arch/arm64/boot/Image
V23_RAMDISK=/mnt/d/TB371FC-builds/arch-development-loader-v23-gated-panel-cycle/tb371fc-arch-development-loader-v23-gated-panel-cycle.cpio.gz
V50_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v50-community-simplefb-arch-ssh
V47_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v47-community-parallel-sspp
STOCK_RECOVERY="$PROJECT/artifacts/device-backup/lun0-recovery_b.bin"
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v51-community-simplefb-arch-remote
OUTPUT_RAMDISK="$OUTPUT_ROOT/tb371fc-v51-simplefb-arch-remote.cpio.gz"
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v51-community-simplefb-arch-remote-recovery.img"
DTB="$V50_ROOT/dtb-community-sspp-simplefb-nomap.img"
RECOVERY_DTBO="$V47_ROOT/recovery-dtbo-avdd-always-on.img"

for input in "$COMMUNITY_KERNEL" "$V23_RAMDISK" "$DTB" \
	"$RECOVERY_DTBO" "$STOCK_RECOVERY" \
	"$PROJECT/initramfs/init-community-simplefb-remote-v51" \
	"$PROJECT/initramfs/setup-usb-remote-v51" \
	"$PROJECT/rootfs/development-overlay/usr/local/sbin/tb371fc-development-init" \
	"$PROJECT/diagnostics/framebuffer-pattern.c"; do
	test -s "$input"
done
mkdir -p "$OUTPUT_ROOT"
test ! -e "$OUTPUT_RAMDISK"
test ! -e "$OUTPUT_IMAGE"

ramdisk_stage=$(mktemp -d)
image_verify=$(mktemp -d)
verify_ramdisk=$(mktemp -d)
trap 'rm -rf -- "$ramdisk_stage" "$image_verify" "$verify_ramdisk"' EXIT

(
	cd "$ramdisk_stage"
	gzip -dc "$V23_RAMDISK" | cpio -idmu 2>/dev/null
)
install -m0755 "$PROJECT/initramfs/init-community-simplefb-remote-v51" \
	"$ramdisk_stage/init"
install -m0755 "$PROJECT/initramfs/setup-usb-remote-v51" \
	"$ramdisk_stage/bin/setup-usb-remote-v51"
install -m0755 \
	"$PROJECT/rootfs/development-overlay/usr/local/sbin/tb371fc-development-init" \
	"$ramdisk_stage/bin/tb371fc-development-init-runtime"
aarch64-linux-gnu-gcc -static -Os -s -Wall -Wextra \
	-o "$ramdisk_stage/bin/framebuffer-pattern" \
	"$PROJECT/diagnostics/framebuffer-pattern.c"
rm -f "$ramdisk_stage/bin/drm-kms-smoketest"
test -x "$ramdisk_stage/bin/boot-arch-development-rootfs"
test -x "$ramdisk_stage/bin/return-to-bootloader"
test ! -e "$ramdisk_stage/bin/drm-kms-smoketest"
(
	cd "$ramdisk_stage"
	find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 \
		2>/dev/null | gzip -9n >"$OUTPUT_RAMDISK"
)

RECOVERY_DTBO="$RECOVERY_DTBO" \
DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 msm_drm.sdecustom=0 video=Virtual-1:d fbcon=font:SUN12x22 fbcon=nodefer' \
	bash "$PROJECT/scripts/build-diagnostic-recovery.sh" \
		/root/mkbootimg/mkbootimg.py \
		/root/mkbootimg/unpack_bootimg.py \
		/root/avb/avbtool.py \
		"$STOCK_RECOVERY" \
		"$COMMUNITY_KERNEL" \
		"$OUTPUT_RAMDISK" \
		"$DTB" \
		"$OUTPUT_IMAGE"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$OUTPUT_IMAGE" --out "$image_verify" --format=info \
	>"$OUTPUT_ROOT/unpack-info.txt"
cmp "$image_verify/kernel" "$COMMUNITY_KERNEL"
cmp "$image_verify/ramdisk" "$OUTPUT_RAMDISK"
cmp "$image_verify/dtb" "$DTB"
cmp "$image_verify/recovery_dtbo" "$RECOVERY_DTBO"
grep -q 'fbcon=font:SUN12x22 fbcon=nodefer' "$OUTPUT_ROOT/unpack-info.txt"

(
	cd "$verify_ramdisk"
	gzip -dc "$OUTPUT_RAMDISK" | cpio -idmu 2>/dev/null
)
sh -n "$verify_ramdisk/init"
sh -n "$verify_ramdisk/bin/setup-usb-remote-v51"
sh -n "$verify_ramdisk/bin/tb371fc-development-init-runtime"
test -x "$verify_ramdisk/bin/framebuffer-pattern"
test -x "$verify_ramdisk/bin/setup-usb-remote-v51"
test ! -e "$verify_ramdisk/bin/drm-kms-smoketest"
qemu-aarch64-static "$verify_ramdisk/bin/busybox" --list \
	>"$image_verify/busybox-applets.txt"
for applet in ash sh cttyhack setsid stty; do
	grep -Fxq "$applet" "$image_verify/busybox-applets.txt"
done
grep -Fq 'functions/acm.GS0' "$verify_ramdisk/bin/setup-usb-remote-v51"
grep -Fq 'echo 0x0104' "$verify_ramdisk/bin/setup-usb-remote-v51"
grep -Fq 'cttyhack busybox sh -i' "$verify_ramdisk/init"
grep -Fq 'serial-rescue-hold' "$verify_ramdisk/init"
! grep -Fq 'exec /bin/boot-arch-development-rootfs' "$verify_ramdisk/init"

sha256sum "$COMMUNITY_KERNEL" "$OUTPUT_RAMDISK" "$DTB" \
	"$RECOVERY_DTBO" "$OUTPUT_IMAGE" >"$OUTPUT_ROOT/SHA256SUMS"
sha256sum -c "$OUTPUT_ROOT/SHA256SUMS"
cat "$OUTPUT_ROOT/SHA256SUMS"
