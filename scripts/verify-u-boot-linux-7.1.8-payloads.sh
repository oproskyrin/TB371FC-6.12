#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

package_dir=${1:-/mnt/d/TB371FC-builds/u-boot-linux-7.1.8-payloads}
release_dir=${RELEASE_DIR:-/mnt/d/TB371FC-builds/linux-7.1.8-tb371fc-offline}
unpack_bootimg=${UNPACK_BOOTIMG:-/root/mkbootimg/unpack_bootimg.py}
initramfs=${INITRAMFS:-/mnt/d/TB371FC-builds/diagnostic-7.1.8-stage0-minimal-initramfs.cpio.gz}
payload_kind=${PAYLOAD_KIND:-diagnostic}
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

case "$payload_kind" in
	diagnostic)
		filename_suffix=
		variants=(stage0 display-test)
		;;
	arch-development)
		filename_suffix=-arch-development
		variants=(arch-test)
		;;
	*) echo "Unsupported PAYLOAD_KIND: $payload_kind" >&2; exit 1 ;;
esac

for input in "$package_dir/README.txt" "$package_dir/SHA256SUMS"; do
	[[ -s $input ]] || { echo "Missing payload artifact: $input" >&2; exit 1; }
done
for variant in "${variants[@]}"; do
	input="$package_dir/tb371fc-linux-7.1.8-$variant$filename_suffix-u-boot.img"
	[[ -s $input ]] || { echo "Missing payload artifact: $input" >&2; exit 1; }
done
(cd "$package_dir" && sha256sum -c SHA256SUMS)
grep -q '^hardware_status=OFFLINE VERIFIED; NOT BOOTED$' "$package_dir/README.txt"
if grep -q '^payload_kind=' "$package_dir/README.txt"; then
	grep -q "^payload_kind=$payload_kind$" "$package_dir/README.txt"
else
	[[ $payload_kind == diagnostic ]]
fi
grep -q '^warning=Do not use fastboot flash' "$package_dir/README.txt"

for variant in "${variants[@]}"; do
	case "$variant" in
	stage0) dtb_name=sm8250-lenovo-tb371fc-stage0 ;;
	display-test) dtb_name=sm8250-lenovo-tb371fc-display-test ;;
	arch-test) dtb_name=sm8250-lenovo-tb371fc-arch-test ;;
	esac
	image="$package_dir/tb371fc-linux-7.1.8-$variant$filename_suffix-u-boot.img"
	out="$stage/$variant"
	python3 "$unpack_bootimg" --boot_img "$image" --out "$out" --format info \
		>"$stage/$variant.info"
	grep -q '^boot image header version: 2$' "$stage/$variant.info"
	grep -q '^page size: 4096$' "$stage/$variant.info"
	gzip -t "$out/kernel"
	gzip -dc "$out/kernel" | cmp - "$release_dir/Image"
	cmp "$out/dtb" "$release_dir/dtb/qcom/$dtb_name.dtb"
	gzip -t "$out/ramdisk"
	cmp "$out/ramdisk" "$initramfs"
	[[ $(stat -c %s "$image") -lt $((112 * 1024 * 1024)) ]]
done

echo "TB371FC U-Boot Linux 7.1.8 $payload_kind payloads verified (offline only)."
