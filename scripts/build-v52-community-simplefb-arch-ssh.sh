#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
COMMUNITY_KERNEL=/root/tb371fc-desktop-working-out-v49/arch/arm64/boot/Image
V23_RAMDISK=/mnt/d/TB371FC-builds/arch-development-loader-v23-gated-panel-cycle/tb371fc-arch-development-loader-v23-gated-panel-cycle.cpio.gz
V50_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v50-community-simplefb-arch-ssh
V47_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v47-community-parallel-sspp
STOCK_RECOVERY="$PROJECT/artifacts/device-backup/lun0-recovery_b.bin"
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v52-community-simplefb-arch-ssh
OUTPUT_RAMDISK="$OUTPUT_ROOT/tb371fc-v52-simplefb-arch-ssh.cpio.gz"
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v52-community-simplefb-arch-ssh-recovery.img"
DTB="$V50_ROOT/dtb-community-sspp-simplefb-nomap.img"
RECOVERY_DTBO="$V47_ROOT/recovery-dtbo-avdd-always-on.img"

for input in "$COMMUNITY_KERNEL" "$V23_RAMDISK" "$DTB" \
	"$RECOVERY_DTBO" "$STOCK_RECOVERY" \
	"$PROJECT/initramfs/init-community-simplefb-ssh-v52" \
	"$PROJECT/initramfs/setup-usb-ncm-v52" \
	"$PROJECT/rootfs/development-overlay/usr/local/sbin/tb371fc-development-init" \
	"$PROJECT/diagnostics/framebuffer-pattern.c"; do
	test -s "$input"
done
mkdir -p "$OUTPUT_ROOT"
test ! -e "$OUTPUT_RAMDISK"
test ! -e "$OUTPUT_IMAGE"

stage=$(mktemp -d)
unpacked=$(mktemp -d)
verify_ramdisk=$(mktemp -d)
trap 'rm -rf -- "$stage" "$unpacked" "$verify_ramdisk"' EXIT

(
	cd "$stage"
	gzip -dc "$V23_RAMDISK" | cpio -idmu 2>/dev/null
)
install -m0755 "$PROJECT/initramfs/init-community-simplefb-ssh-v52" "$stage/init"
install -m0755 "$PROJECT/initramfs/setup-usb-ncm-v52" "$stage/bin/setup-usb-ncm-v52"
install -m0755 \
	"$PROJECT/rootfs/development-overlay/usr/local/sbin/tb371fc-development-init" \
	"$stage/bin/tb371fc-development-init-runtime"
aarch64-linux-gnu-gcc -static -Os -s -Wall -Wextra \
	-o "$stage/bin/framebuffer-pattern" \
	"$PROJECT/diagnostics/framebuffer-pattern.c"
rm -f "$stage/bin/drm-kms-smoketest"
test -x "$stage/bin/boot-arch-development-rootfs"
test -x "$stage/bin/return-to-bootloader"
(
	cd "$stage"
	find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 \
		2>/dev/null | gzip -9n >"$OUTPUT_RAMDISK"
)

RECOVERY_DTBO="$RECOVERY_DTBO" \
DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 msm_drm.sdecustom=0 video=Virtual-1:d fbcon=font:SUN12x22 fbcon=nodefer' \
	bash "$PROJECT/scripts/build-diagnostic-recovery.sh" \
		/root/mkbootimg/mkbootimg.py \
		/root/mkbootimg/unpack_bootimg.py \
		/root/avb/avbtool.py \
		"$STOCK_RECOVERY" "$COMMUNITY_KERNEL" "$OUTPUT_RAMDISK" \
		"$DTB" "$OUTPUT_IMAGE"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$OUTPUT_IMAGE" --out "$unpacked" --format=info \
	>"$OUTPUT_ROOT/unpack-info.txt"
cmp "$unpacked/kernel" "$COMMUNITY_KERNEL"
cmp "$unpacked/ramdisk" "$OUTPUT_RAMDISK"
cmp "$unpacked/dtb" "$DTB"
cmp "$unpacked/recovery_dtbo" "$RECOVERY_DTBO"
grep -q 'fbcon=font:SUN12x22 fbcon=nodefer' "$OUTPUT_ROOT/unpack-info.txt"

(
	cd "$verify_ramdisk"
	gzip -dc "$OUTPUT_RAMDISK" | cpio -idmu 2>/dev/null
)
sh -n "$verify_ramdisk/init"
sh -n "$verify_ramdisk/bin/setup-usb-ncm-v52"
sh -n "$verify_ramdisk/bin/tb371fc-development-init-runtime"
test -x "$verify_ramdisk/bin/framebuffer-pattern"
test -x "$verify_ramdisk/bin/boot-arch-development-rootfs"
test -x "$verify_ramdisk/bin/return-to-bootloader"
test ! -e "$verify_ramdisk/bin/drm-kms-smoketest"
qemu-aarch64-static "$verify_ramdisk/bin/busybox" --list >"$unpacked/busybox-applets.txt"
for applet in ash sh ip ifconfig nc seq; do
	grep -Fxq "$applet" "$unpacked/busybox-applets.txt"
done
grep -Fq 'functions/ncm.usb0' "$verify_ramdisk/bin/setup-usb-ncm-v52"
grep -Fq 'echo 0x0105' "$verify_ramdisk/bin/setup-usb-ncm-v52"
! grep -Fq 'functions/acm.GS0' "$verify_ramdisk/bin/setup-usb-ncm-v52"
grep -Fq '169.254.77.2/16' "$verify_ramdisk/init"
grep -Fq 'exec /bin/boot-arch-development-rootfs' "$verify_ramdisk/init"
grep -Fq 'Arch OpenSSH: 169.254.77.2 port 2222' "$verify_ramdisk/init"

sha256sum "$COMMUNITY_KERNEL" "$OUTPUT_RAMDISK" "$DTB" \
	"$RECOVERY_DTBO" "$OUTPUT_IMAGE" >"$OUTPUT_ROOT/SHA256SUMS"
sha256sum -c "$OUTPUT_ROOT/SHA256SUMS"
cat "$OUTPUT_ROOT/SHA256SUMS"

