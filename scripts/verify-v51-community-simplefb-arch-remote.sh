#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

OUTPUT_ROOT=${1:-/mnt/d/TB371FC-builds/arch-development-loader-v51-community-simplefb-arch-remote}
OUTPUT_RAMDISK="$OUTPUT_ROOT/tb371fc-v51-simplefb-arch-remote.cpio.gz"
OUTPUT_IMAGE="$OUTPUT_ROOT/tb371fc-arch-development-loader-v51-community-simplefb-arch-remote-recovery.img"

test -s "$OUTPUT_IMAGE"
test -s "$OUTPUT_RAMDISK"
test -s "$OUTPUT_ROOT/SHA256SUMS"

stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
(
	cd "$stage"
	gzip -dc "$OUTPUT_RAMDISK" | cpio -idmu 2>/dev/null
)

sh -n "$stage/init"
sh -n "$stage/bin/setup-usb-remote-v51"
test -x "$stage/bin/return-to-bootloader"
test ! -e "$stage/bin/drm-kms-smoketest"

qemu-aarch64-static "$stage/bin/busybox" --list >"$stage/busybox-applets.txt"
for applet in ash sh cttyhack setsid stty; do
	grep -Fxq "$applet" "$stage/busybox-applets.txt"
done

grep -Fq 'functions/acm.GS0' "$stage/bin/setup-usb-remote-v51"
grep -Fq 'echo 0x0104' "$stage/bin/setup-usb-remote-v51"
grep -Fq 'cttyhack busybox sh -i' "$stage/init"
grep -Fq 'serial-rescue-hold' "$stage/init"
! grep -Fq 'exec /bin/boot-arch-development-rootfs' "$stage/init"

(
	cd "$OUTPUT_ROOT"
	sha256sum -c SHA256SUMS
)
echo 'V51 ACM ash image verification: PASS'
