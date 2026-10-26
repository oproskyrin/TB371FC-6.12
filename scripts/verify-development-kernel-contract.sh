#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 4 )); then
	echo "Usage: $0 IMAGE INITRAMFS DEVELOPMENT_ROOT_IMAGE EXTRACT_IKCONFIG" >&2
	exit 2
fi
[[ $EUID == 0 ]]

kernel=$(realpath "$1")
initramfs=$(realpath "$2")
root_image=$(realpath "$3")
extract_ikconfig=$(realpath "$4")
expected_release=4.19.325-cip134-st18-perf+

stage=$(mktemp -d)
root_mount=$(mktemp -d)
mounted=0
cleanup() {
	(( mounted == 0 )) || umount "$root_mount" 2>/dev/null || true
	rm -rf -- "$stage" "$root_mount"
}
trap cleanup EXIT

strings "$kernel" >"$stage/kernel.strings"
version=$(grep -m1 '^Linux version ' "$stage/kernel.strings")
[[ $version == "Linux version $expected_release "* ]]
"$extract_ikconfig" "$kernel" >"$stage/kernel.config"
for option in \
	CONFIG_CNSS2_DIAGNOSTIC_SINGLE_QMI_CLIENT=y \
	CONFIG_DRM_FBDEV_EMULATION=y \
	CONFIG_FRAMEBUFFER_CONSOLE=y \
	CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y \
	CONFIG_VT=y \
	CONFIG_VT_CONSOLE=y; do
	grep -Fxq "$option" "$stage/kernel.config"
done

(
	cd "$stage"
	gzip -dc "$initramfs" | cpio -idmu 2>/dev/null
)
mapfile -t modules < <(find \
	"$stage/lib/modules/$expected_release" \
	"$stage/usr/lib/modules/$expected_release" \
	-type f -name '*.ko' 2>/dev/null | sort -u)
(( ${#modules[@]} > 0 ))
for module in "${modules[@]}"; do
	vermagic=$(modinfo -F vermagic "$module")
	[[ $vermagic == "$expected_release "* ]]
done

mount -o ro,noload,loop "$root_image" "$root_mount"
mounted=1
grep -qx "kernel_release=$expected_release" \
	"$root_mount/etc/tb371fc-development-image"
return_module="$root_mount/usr/lib/modules/$expected_release/extra/reboot-bootloader.ko"
[[ -s $return_module ]]
return_vermagic=$(modinfo -F vermagic "$return_module")
[[ $return_vermagic == "$expected_release "* ]]

echo "Verified kernel/initramfs/rootfs release contract: $expected_release"
echo "Verified ${#modules[@]} initramfs modules and the bootloader-return module."
sha256sum "$kernel" "$initramfs"
