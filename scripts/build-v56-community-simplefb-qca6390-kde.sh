#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
V56_RELEASE=/root/tb371fc-desktop-v56-kde-wlan-release
COMMUNITY_KERNEL=$V56_RELEASE/Image
WLAN_MODULE=$V56_RELEASE/wlan.ko
V55_RAMDISK=/mnt/d/TB371FC-builds/arch-development-loader-v55-community-simplefb-arch-loopback-ssh/tb371fc-v55-simplefb-arch-loopback-ssh.cpio.gz
V55_RECOVERY=/mnt/d/TB371FC-builds/arch-development-loader-v55-community-simplefb-arch-loopback-ssh/tb371fc-arch-development-loader-v55-community-simplefb-arch-loopback-ssh-recovery.img
STOCK_RECOVERY="$PROJECT/artifacts/device-backup/lun0-recovery_b.bin"
OUTPUT_ROOT=/mnt/d/TB371FC-builds/arch-development-loader-v56-community-simplefb-qca6390-kde
OUTPUT_RAMDISK="$OUTPUT_ROOT/tb371fc-v56-simplefb-qca6390-kde.cpio.gz"
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v56-community-simplefb-qca6390-kde-recovery.img"

for input in "$COMMUNITY_KERNEL" "$WLAN_MODULE" "$V56_RELEASE/kernel.release" \
	"$V55_RAMDISK" "$V55_RECOVERY" "$STOCK_RECOVERY" \
	"$PROJECT/initramfs/init-community-simplefb-gated-ssh-v56" \
	"$PROJECT/initramfs/setup-usb-acm-v56" \
	"$PROJECT/initramfs/start-v56-services" \
	"$PROJECT/initramfs/boot-arch-development-rootfs" \
	"$PROJECT/initramfs/collect-hardware-snapshot" \
	"$PROJECT/initramfs/capture-input-events" \
	"$PROJECT/rootfs/development-overlay/usr/local/sbin/tb371fc-development-init" \
	"$PROJECT/diagnostics/framebuffer-pattern.c"; do
	test -s "$input"
done
printf '%s  %s\n' \
	'c03331d9f85e33c490c6bfe8892d6b118b5283680c18729e9897d69228a4e9e5' \
	"$V55_RECOVERY" | sha256sum -c -
kernel_release=$(cat "$V56_RELEASE/kernel.release")
case "$kernel_release" in
	4.19.157-perf-v56*) ;;
	*) echo "Refusing unexpected V56 release: $kernel_release" >&2; exit 2 ;;
esac

mkdir -p "$OUTPUT_ROOT"
test ! -e "$OUTPUT_RAMDISK"
test ! -e "$OUTPUT_IMAGE"

stage=$(mktemp -d)
base_unpacked=$(mktemp -d)
unpacked=$(mktemp -d)
verify_ramdisk=$(mktemp -d)
trap 'rm -rf -- "$stage" "$base_unpacked" "$unpacked" "$verify_ramdisk"' EXIT

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$V55_RECOVERY" --out "$base_unpacked" --format=info \
	>"$OUTPUT_ROOT/v55-base-unpack-info.txt"
DTB="$base_unpacked/dtb"
RECOVERY_DTBO="$base_unpacked/recovery_dtbo"
test -s "$DTB"
test -s "$RECOVERY_DTBO"

(
	cd "$stage"
	gzip -dc "$V55_RAMDISK" | cpio -idmu 2>/dev/null
)
install -m0755 "$PROJECT/initramfs/init-community-simplefb-gated-ssh-v56" "$stage/init"
install -m0755 "$PROJECT/initramfs/setup-usb-acm-v56" "$stage/bin/setup-usb-acm-v56"
install -m0755 "$PROJECT/initramfs/start-v56-services" "$stage/bin/start-v56-services"
install -m0644 "$WLAN_MODULE" "$stage/bin/wlan-v56.ko"
install -m0755 "$PROJECT/initramfs/boot-arch-development-rootfs" \
	"$stage/bin/boot-arch-development-rootfs"
install -m0755 "$PROJECT/initramfs/collect-hardware-snapshot" \
	"$stage/bin/collect-hardware-snapshot"
install -m0755 "$PROJECT/initramfs/capture-input-events" \
	"$stage/bin/capture-input-events"
install -m0755 \
	"$PROJECT/rootfs/development-overlay/usr/local/sbin/tb371fc-development-init" \
	"$stage/bin/tb371fc-development-init-runtime"
aarch64-linux-gnu-gcc -static -Os -s -Wall -Wextra \
	-o "$stage/bin/framebuffer-pattern" \
	"$PROJECT/diagnostics/framebuffer-pattern.c"
rm -f "$stage/bin/drm-kms-smoketest"
test -x "$stage/bin/input-monitor"
test -x "$stage/bin/return-to-bootloader"
(
	cd "$stage"
	find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 \
		2>/dev/null | gzip -9n >"$OUTPUT_RAMDISK"
)

RECOVERY_DTBO="$RECOVERY_DTBO" \
DIAGNOSTIC_CMDLINE='earlycon=qcom_geni,0x988000 console=ttyMSM0,115200n8 console=tty0 keep_bootcon ignore_loglevel rdinit=/init root=/dev/ram0 rw fw_devlink=permissive clk_ignore_unused pd_ignore_unused regulator_ignore_unused panic=-1 swiotlb=2048 msm_drm.sdecustom=0 video=Virtual-1:d fbcon=font:SUN12x22 fbcon=nodefer' \
	bash "$PROJECT/scripts/build-diagnostic-recovery.sh" \
		/root/mkbootimg/mkbootimg.py /root/mkbootimg/unpack_bootimg.py \
		/root/avb/avbtool.py "$STOCK_RECOVERY" "$COMMUNITY_KERNEL" \
		"$OUTPUT_RAMDISK" "$DTB" "$OUTPUT_IMAGE"

python3 /root/mkbootimg/unpack_bootimg.py \
	--boot_img "$OUTPUT_IMAGE" --out "$unpacked" --format=info \
	>"$OUTPUT_ROOT/unpack-info.txt"
cmp "$unpacked/kernel" "$COMMUNITY_KERNEL"
cmp "$unpacked/ramdisk" "$OUTPUT_RAMDISK"
cmp "$unpacked/dtb" "$DTB"
cmp "$unpacked/recovery_dtbo" "$RECOVERY_DTBO"
install -m0644 "$COMMUNITY_KERNEL" "$OUTPUT_ROOT/Image-v56"
install -m0644 "$WLAN_MODULE" "$OUTPUT_ROOT/wlan-v56.ko"
install -m0644 "$V56_RELEASE/kernel.config" "$OUTPUT_ROOT/kernel-v56.config"
install -m0644 "$V56_RELEASE/kernel.release" "$OUTPUT_ROOT/kernel.release"
install -m0644 "$DTB" "$OUTPUT_ROOT/dtb-v56.img"
install -m0644 "$RECOVERY_DTBO" "$OUTPUT_ROOT/recovery-dtbo-v56.img"

(
	cd "$verify_ramdisk"
	gzip -dc "$OUTPUT_RAMDISK" | cpio -idmu 2>/dev/null
)
for script in init bin/setup-usb-acm-v56 bin/start-v56-services \
	bin/boot-arch-development-rootfs bin/collect-hardware-snapshot \
	bin/capture-input-events bin/tb371fc-development-init-runtime; do
	sh -n "$verify_ramdisk/$script"
done
for binary in framebuffer-pattern input-monitor return-to-bootloader \
	collect-hardware-snapshot capture-input-events; do
	test -x "$verify_ramdisk/bin/$binary"
done
test -s "$verify_ramdisk/bin/wlan-v56.ko"
cmp "$verify_ramdisk/bin/wlan-v56.ko" "$WLAN_MODULE"
test -z "$(find "$verify_ramdisk" -type f -name '*.nmconnection' -print -quit)"
test ! -e "$verify_ramdisk/bin/drm-kms-smoketest"
qemu-aarch64-static "$verify_ramdisk/bin/busybox" --list >"$unpacked/busybox-applets.txt"
for applet in ash sh grep ip nc sed seq stty tail; do
	grep -Fxq "$applet" "$unpacked/busybox-applets.txt"
done
grep -Fq 'functions/acm.GS0' "$verify_ramdisk/bin/setup-usb-acm-v56"
grep -Fq '__TB371FC_SSH_GATE_READY__' \
	"$verify_ramdisk/bin/tb371fc-development-init-runtime"
grep -Fq '4.19.157-perf-v56' "$verify_ramdisk/bin/start-v56-services"
grep -Fq 'startplasma-wayland' "$verify_ramdisk/bin/start-v56-services"
grep -Fq 'LIBGL_ALWAYS_SOFTWARE=1' "$verify_ramdisk/bin/start-v56-services"
grep -Fq 'wlan-v56.ko' "$verify_ramdisk/bin/boot-arch-development-rootfs"
grep -Fq 'start-v56-services' "$verify_ramdisk/bin/boot-arch-development-rootfs"
readelf -p .modinfo "$verify_ramdisk/bin/wlan-v56.ko" \
	>"$OUTPUT_ROOT/wlan.modinfo.txt"
grep -Fq "vermagic=$kernel_release " "$OUTPUT_ROOT/wlan.modinfo.txt"
tail -c 64 "$verify_ramdisk/bin/wlan-v56.ko" | \
	grep -Fq '~Module signature appended~'

(
	cd "$OUTPUT_ROOT"
	sha256sum Image-v56 wlan-v56.ko kernel-v56.config kernel.release \
		tb371fc-v56-simplefb-qca6390-kde.cpio.gz dtb-v56.img \
		recovery-dtbo-v56.img \
		tb371fc-arch-development-loader-v56-community-simplefb-qca6390-kde-recovery.img \
		>SHA256SUMS
	sha256sum -c SHA256SUMS
	cat SHA256SUMS
)
