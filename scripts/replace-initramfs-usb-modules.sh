#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 3 )); then
	echo "Usage: $0 INPUT_INITRAMFS KERNEL_OUT OUTPUT_INITRAMFS" >&2
	exit 2
fi

input=$(realpath "$1")
kernel_out=$(realpath "$2")
output=$(realpath -m "$3")
[[ ! -e $output ]] || {
	echo "Refusing to overwrite existing initramfs: $output" >&2
	exit 1
}

module_relpaths=(
	drivers/usb/gadget/libcomposite.ko
	drivers/usb/gadget/function/u_serial.ko
	drivers/usb/gadget/function/usb_f_acm.ko
)
for relative in "${module_relpaths[@]}"; do
	[[ -f $kernel_out/$relative ]] || {
		echo "Missing required module: $kernel_out/$relative" >&2
		exit 1
	}
done

release=$(modinfo -F vermagic "$kernel_out/${module_relpaths[0]}" | awk '{print $1}')
[[ -n $release ]] || {
	echo "Unable to determine module release" >&2
	exit 1
}
for relative in "${module_relpaths[@]}"; do
	module_release=$(modinfo -F vermagic "$kernel_out/$relative" | awk '{print $1}')
	[[ $module_release == "$release" ]] || {
		echo "Module release mismatch: $relative: $module_release != $release" >&2
		exit 1
	}
done

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
modules_root="$stage/usr/lib/modules"
[[ -d $modules_root ]] || {
	echo "Input initramfs has no module tree" >&2
	exit 1
}
find "$modules_root" -mindepth 1 -maxdepth 1 -type d -exec rm -rf -- {} +
release_root="$modules_root/$release"
mkdir -p "$release_root"
for relative in "${module_relpaths[@]}"; do
	install -Dm0644 "$kernel_out/$relative" "$release_root/kernel/$relative"
done
for metadata in modules.builtin modules.builtin.modinfo modules.order; do
	[[ -f $kernel_out/$metadata ]] &&
		install -m0644 "$kernel_out/$metadata" "$release_root/$metadata"
done
depmod -b "$stage" "$release"

mkdir -p "$(dirname "$output")"
(
	cd "$stage"
	find . -print0 | sort -z |
		cpio --null -o --format=newc --owner=0:0 2>/dev/null |
		gzip -9n >"$output_tmp"
)
mv -T "$output_tmp" "$output"
gzip -t "$output"
echo "Minimal USB diagnostic initramfs: $output"
echo "Kernel release: $release"
sha256sum "$output"
