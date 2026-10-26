#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 1 )); then
	echo "Usage: $0 DEVELOPMENT_INITRAMFS" >&2
	exit 2
fi
[[ $EUID == 0 ]]

image=$(realpath "$1")
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
(
	cd "$stage"
	gzip -dc "$image" | cpio -idmu 2>/dev/null
)
export TB371FC_TEST_BUSYBOX="$stage/bin/busybox"

unshare -n -- bash -eu -c '
	ip link add usb0 type dummy
	qemu-aarch64-static "$TB371FC_TEST_BUSYBOX" ip link set usb0 up
	qemu-aarch64-static "$TB371FC_TEST_BUSYBOX" ip addr add \
		169.254.77.2/16 dev usb0
	qemu-aarch64-static "$TB371FC_TEST_BUSYBOX" ip addr show dev usb0 |
		grep -q "inet 169.254.77.2/16"
'

echo 'Verified ARM64 BusyBox can set usb0 UP and add 169.254.77.2/16.'
