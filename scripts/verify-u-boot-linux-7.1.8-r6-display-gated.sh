#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

release_dir=${RELEASE_DIR:-/mnt/d/TB371FC-builds/linux-7.1.8-tb371fc-r6-display-wideplane-offline}
package_dir=${1:-/mnt/d/TB371FC-builds/u-boot-linux-7.1.8-r6-display-gated-payload}
unpack_bootimg=${UNPACK_BOOTIMG:-/root/mkbootimg/unpack_bootimg.py}
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

image="$package_dir/tb371fc-linux-7.1.8-display-gated-u-boot.img"
ramdisk="$package_dir/tb371fc-linux-7.1.8-display-gated-initramfs.cpio.gz"
dtb="$release_dir/dtb/qcom/sm8250-lenovo-tb371fc-display-test.dtb"
for input in "$image" "$ramdisk" "$dtb" "$package_dir/README.txt" \
	"$package_dir/SHA256SUMS"; do
	[[ -s $input ]] || { echo "Missing gated display artifact: $input" >&2; exit 1; }
done

(cd "$package_dir" && sha256sum -c SHA256SUMS)
grep -q '^payload_kind=display-gated$' "$package_dir/README.txt"
grep -q '^automatic_modeset=disabled$' "$package_dir/README.txt"
grep -q '^hardware_status=OFFLINE VERIFIED; NOT BOOTED$' "$package_dir/README.txt"

python3 "$unpack_bootimg" --boot_img "$image" --out "$stage/unpack" --format info \
	>"$stage/boot.info"
grep -q '^boot image header version: 2$' "$stage/boot.info"
grep -q 'drm.debug=0x1ff' "$stage/boot.info"
grep -q 'drm_kms_helper.fbdev_emulation=0' "$stage/boot.info"
grep -q 'msm.fbdev=0' "$stage/boot.info"
gzip -t "$stage/unpack/kernel"
gzip -dc "$stage/unpack/kernel" | cmp - "$release_dir/Image"
cmp "$stage/unpack/dtb" "$dtb"
cmp "$stage/unpack/ramdisk" "$ramdisk"
[[ $(fdtget -t s "$dtb" /soc@0/display-subsystem@ae00000/display-controller@ae01000 compatible) == lenovo,tb371fc-dpu ]]
[[ $(stat -c %s "$image") -lt $((112 * 1024 * 1024)) ]]

mkdir "$stage/initramfs"
(
	cd "$stage/initramfs"
	gzip -dc "$ramdisk" | cpio -id --quiet
)
for tool in drm-kms-smoketest reboot-bootloader snapshot-mainline-display \
	run-mainline-display-test status-mainline-display-test; do
	[[ -x $stage/initramfs/bin/$tool ]] || { echo "Missing tool: $tool" >&2; exit 1; }
done
file "$stage/initramfs/bin/drm-kms-smoketest" | grep -q 'ARM aarch64.*statically linked'
grep -q 'no native modeset has been requested yet' "$stage/initramfs/init"
grep -q 'run-mainline-display-test 120 checker 120' "$stage/initramfs/init"
if grep -Eq '^[[:space:]]*(exec[[:space:]]+)?drm-kms-smoketest' "$stage/initramfs/init"; then
	echo 'Initramfs init must not perform an automatic KMS modeset' >&2
	exit 1
fi

echo 'TB371FC Linux 7.1.8 r6 gated display payload verified (offline only).'
sha256sum "$image" "$ramdisk"

