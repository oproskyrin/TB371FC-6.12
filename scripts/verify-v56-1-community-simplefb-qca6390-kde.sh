#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

SOURCE=/root/tb371fc-desktop-v56-1-kde-wlan-safe-src
OUTPUT=/root/tb371fc-desktop-v56-1-kde-wlan-safe-out
RELEASE=/root/tb371fc-desktop-v56-1-kde-wlan-safe-release
PACKAGE=/mnt/d/TB371FC-builds/arch-development-loader-v56-1-community-simplefb-qca6390-kde-safe
V55=/mnt/d/TB371FC-builds/arch-development-loader-v55-community-simplefb-arch-loopback-ssh/tb371fc-arch-development-loader-v55-community-simplefb-arch-loopback-ssh-recovery.img
V56=/mnt/d/TB371FC-builds/arch-development-loader-v56-community-simplefb-qca6390-kde/tb371fc-arch-development-loader-v56-community-simplefb-qca6390-kde-recovery.img

git -C "$SOURCE" diff --check
grep -n 'userspace_test_only' \
	"$SOURCE/include/drm/drm_atomic.h" \
	"$SOURCE/drivers/gpu/drm/drm_atomic.c" \
	"$SOURCE/techpack/display/msm/sde/sde_rm.c"
strings "$OUTPUT/vmlinux" | \
	grep -F 'userspace test_only: discard rsvp' >/dev/null
grep -Fqx 'CONFIG_CNSS2_DIAGNOSTIC_NO_SSR=y' "$RELEASE/kernel.config"
grep -Fqx 'CONFIG_CNSS2_DIAGNOSTIC_SINGLE_QMI_CLIENT=y' \
	"$RELEASE/kernel.config"
grep -Fqx '4.19.157-perf-v56.1+' "$RELEASE/kernel.release"

(
	cd "$PACKAGE"
	sha256sum -c SHA256SUMS
)
printf '%s  %s\n' \
	'c03331d9f85e33c490c6bfe8892d6b118b5283680c18729e9897d69228a4e9e5' \
	"$V55" | sha256sum -c -
printf '%s  %s\n' \
	'943a658b99065d59fd40c56a3f792938aa306669d8963511559d3a07942c8cd5' \
	"$V56" | sha256sum -c -

stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
(
	cd "$stage"
	gzip -dc "$PACKAGE/tb371fc-v56-1-simplefb-qca6390-kde-safe.cpio.gz" | \
		cpio -idmu 2>/dev/null
)
file "$stage/bin/return-to-bootloader" "$stage/bin/wlan-v56.ko"
set +e
qemu-aarch64-static "$stage/bin/return-to-bootloader" WRONG_TOKEN \
	>/dev/null 2>&1
return_rc=$?
set -e
[ "$return_rc" -eq 2 ]
sh -n "$stage/init"
sh -n "$stage/bin/start-v56-services"

echo OFFLINE_V56_1_QA_OK
