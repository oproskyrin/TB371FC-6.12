#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 1 )); then
	echo "Usage: $0 INITRAMFS" >&2
	exit 2
fi

initramfs=$(realpath "$1")
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

(
	cd "$stage"
	gzip -dc "$initramfs" | cpio -idmu 2>/dev/null
)
qemu-aarch64-static "$stage/bin/busybox" --list |
	grep -E '^(telnetd|nc|httpd|reboot|sleep)$' || true
