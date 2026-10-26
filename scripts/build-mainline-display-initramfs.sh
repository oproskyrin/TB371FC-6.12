#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# < 1 || $# > 2 )); then
	echo "Usage: $0 STATIC_AARCH64_BUSYBOX [OUTPUT]" >&2
	exit 2
fi

busybox=$(realpath "$1")
output=$(realpath -m "${2:-artifacts/tb371fc-mainline-display-initramfs.cpio.gz}")
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stage=$(mktemp -d)
mkdir -p "$(dirname "$output")"
output_tmp=$(mktemp "$(dirname "$output")/.tb371fc-display-initramfs.XXXXXX")
cleanup() {
	rm -rf -- "$stage"
	rm -f -- "$output_tmp"
}
trap cleanup EXIT

[[ ! -e $output ]] || {
	echo "Refusing to overwrite existing initramfs: $output" >&2
	exit 1
}
file "$busybox" | grep -q 'ARM aarch64.*statically linked'
mkdir -p "$stage"/{bin,sbin,etc,proc,sys,dev,run,tmp,usr/bin,usr/sbin}
install -m 0755 "$busybox" "$stage/bin/busybox"
install -m 0755 "$project_dir/initramfs/init-mainline-display" "$stage/init"
install -m 0755 "$project_dir/initramfs/setup-usb-console" \
	"$stage/bin/setup-usb-console"
aarch64-linux-gnu-gcc -static -Os -s -Wall -Wextra -Werror \
	-o "$stage/bin/framebuffer-pattern" \
	"$project_dir/diagnostics/framebuffer-pattern.c"
aarch64-linux-gnu-gcc -static -Os -s -Wall -Wextra -Werror \
	-o "$stage/bin/reboot-bootloader" \
	"$project_dir/diagnostics/reboot-bootloader-userspace.c"

for applet in sh mount mkdir hostname dmesg cat tr ls find grep basename uname \
	setsid cttyhack poweroff getty ln ip ifconfig reboot sleep seq; do
	ln -s busybox "$stage/bin/$applet"
done
mknod -m 600 "$stage/dev/console" c 5 1
mknod -m 666 "$stage/dev/null" c 1 3

(
	cd "$stage"
	find . -print0 | sort -z | cpio --null -o --format=newc --owner=0:0 \
		2>/dev/null | gzip -9n >"$output_tmp"
)
mv -T "$output_tmp" "$output"
echo "Mainline display initramfs: $output"
sha256sum "$output" "$stage/bin/framebuffer-pattern"
