#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

SOURCE=/root/tb371fc-desktop-v56-2-kde-wlan-fhandle-src
OUTPUT=/root/tb371fc-desktop-v56-2-kde-wlan-fhandle-out
RELEASE=/root/tb371fc-desktop-v56-2-kde-wlan-fhandle-release
PACKAGE=/mnt/d/TB371FC-builds/arch-development-loader-v56-2-community-simplefb-qca6390-kde-fhandle-safe
V55=/mnt/d/TB371FC-builds/arch-development-loader-v55-community-simplefb-arch-loopback-ssh/tb371fc-arch-development-loader-v55-community-simplefb-arch-loopback-ssh-recovery.img
V56_1=/mnt/d/TB371FC-builds/arch-development-loader-v56-1-community-simplefb-qca6390-kde-safe/tb371fc-arch-development-loader-v56-1-community-simplefb-qca6390-kde-safe-recovery.img

git -C "$SOURCE" diff --check
strings "$OUTPUT/vmlinux" | \
	grep -F 'userspace test_only: discard rsvp' >/dev/null
grep -Fqx 'CONFIG_FHANDLE=y' "$RELEASE/kernel.config"
grep -Fqx 'CONFIG_CNSS2_DIAGNOSTIC_NO_SSR=y' "$RELEASE/kernel.config"
grep -Fqx 'CONFIG_CNSS2_DIAGNOSTIC_SINGLE_QMI_CLIENT=y' \
	"$RELEASE/kernel.config"
grep -Fqx '4.19.157-perf-v56.2+' "$RELEASE/kernel.release"

(
	cd "$PACKAGE"
	sha256sum -c SHA256SUMS
)
printf '%s  %s\n' \
	'c03331d9f85e33c490c6bfe8892d6b118b5283680c18729e9897d69228a4e9e5' \
	"$V55" | sha256sum -c -
printf '%s  %s\n' \
	'0cdf91ede1f046e2e842e3d6b21162c32b2e8b4562da8f6921c15718b4e3a710' \
	"$V56_1" | sha256sum -c -

stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
(
	cd "$stage"
	gzip -dc "$PACKAGE/tb371fc-v56-2-simplefb-qca6390-kde-fhandle-safe.cpio.gz" | \
		cpio -idmu 2>/dev/null
)
sh -n "$stage/init"
sh -n "$stage/bin/start-v56-services"
grep -Fq 'CONFIG_FHANDLE=y' "$stage/bin/start-v56-services"
grep -Fq 'systemd-udevd --daemon' "$stage/bin/start-v56-services"
grep -Fq 'connect_wlan_without_udev' "$stage/bin/start-v56-services"
grep -Fq 'Asia/Yekaterinburg' "$stage/bin/start-v56-services"
grep -Fq 'Autolock false' "$stage/bin/start-v56-services"

set +e
qemu-aarch64-static "$stage/bin/return-to-bootloader" WRONG_TOKEN \
	>/dev/null 2>&1
return_rc=$?
set -e
[ "$return_rc" -eq 2 ]

echo OFFLINE_V56_2_QA_OK
