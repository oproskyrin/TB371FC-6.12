#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 2 )); then
	echo "Usage: $0 INPUT_INITRAMFS OUTPUT_INITRAMFS" >&2
	exit 2
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
input=$(realpath "$1")
output=$(realpath -m "$2")
[[ ! -e $output ]] || {
	echo "Refusing to overwrite existing initramfs: $output" >&2
	exit 1
}

stage=$(mktemp -d)
output_tmp=$(mktemp "$(dirname "$output")/.tb371fc-development.XXXXXX")
cleanup() {
	rm -rf -- "$stage"
	rm -f -- "$output_tmp"
}
trap cleanup EXIT

(
	cd "$stage"
	gzip -dc "$input" | cpio -idmu 2>/dev/null
)

install -m0755 "$repo_dir/initramfs/init-development" "$stage/init"
install -m0755 "$repo_dir/initramfs/setup-usb-console" \
	"$stage/bin/setup-usb-console"
install -m0755 "$repo_dir/initramfs/boot-arch-development-rootfs" \
	"$stage/bin/boot-arch-development-rootfs"
install -m0755 \
	"$repo_dir/rootfs/development-overlay/usr/local/sbin/tb371fc-development-init" \
	"$stage/bin/tb371fc-development-init-runtime"
if [[ ! -x $stage/bin/return-to-bootloader ]]; then
	aarch64-linux-gnu-gcc -static -Os -s -Wall -Wextra -Werror \
		-o "$stage/bin/return-to-bootloader" \
		"$repo_dir/diagnostics/reboot-bootloader-userspace.c"
fi
if [[ -n ${KMS_SMOKETEST:-} ]]; then
	kms_smoketest=$(realpath "$KMS_SMOKETEST")
	file "$kms_smoketest" | grep -q 'ARM aarch64.*statically linked'
	install -m0755 "$kms_smoketest" "$stage/bin/drm-kms-smoketest"
fi
if [[ -n ${KEXEC_BINARY:-} ]]; then
	kexec_binary=$(realpath "$KEXEC_BINARY")
	kexec_loader=${KEXEC_LOADER:-$repo_dir/initramfs/load-mainline-kexec}
	kexec_loader=$(realpath "$kexec_loader")
	file "$kexec_binary" | grep -q 'ARM aarch64.*statically linked'
	install -m0755 "$kexec_binary" "$stage/bin/kexec"
	install -m0755 "$repo_dir/initramfs/start-kexec-receiver" \
		"$stage/bin/start-kexec-receiver"
	install -m0755 "$kexec_loader" \
		"$stage/bin/load-mainline-kexec"
	install -m0755 "$repo_dir/initramfs/execute-mainline-kexec" \
		"$stage/bin/execute-mainline-kexec"
fi
for applet in blkid chmod chroot cp kill ln losetup nc seq stat switch_root sync umount; do
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
echo "TB371FC development-loader initramfs: $output"
sha256sum "$output"
