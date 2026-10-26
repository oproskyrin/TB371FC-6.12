#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 2 )); then
	echo "Usage: $0 INPUT_INITRAMFS OUTPUT_INITRAMFS" >&2
	exit 2
fi

input=$(realpath "$1")
output=$(realpath -m "$2")
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[[ ! -e $output ]] || {
	echo "Refusing to overwrite existing initramfs: $output" >&2
	exit 1
}

stage=$(mktemp -d)
output_tmp=$(mktemp "$(dirname "$output")/.tb371fc-initramfs.XXXXXX")
cleanup() {
	rm -rf -- "$stage"
	rm -f -- "$output_tmp"
}
trap cleanup EXIT

(
	cd "$stage"
	gzip -dc "$input" | cpio -idmu 2>/dev/null
)
install -m0755 "$repo_dir/initramfs/init" "$stage/init"
install -m0755 "$repo_dir/initramfs/setup-usb-console" \
	"$stage/bin/setup-usb-console"
for applet in nc reboot sleep; do
	ln -sf busybox "$stage/bin/$applet"
done

(
	cd "$stage"
	find . -print0 | sort -z |
		cpio --null -o --format=newc --owner=0:0 2>/dev/null |
		gzip -9n >"$output_tmp"
)
mv -T "$output_tmp" "$output"
gzip -t "$output"
echo "Adapted diagnostic initramfs: $output"
sha256sum "$output"
