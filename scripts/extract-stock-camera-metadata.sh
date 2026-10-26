#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
set -euo pipefail

if [[ $# -ne 2 ]]; then
	echo "Usage: $0 VENDOR_EXT4_IMAGE OUTPUT_DIR" >&2
	exit 2
fi
[[ $EUID -eq 0 ]] || {
	echo "Run as root; the vendor image is mounted read-only." >&2
	exit 1
}

vendor_image=$(realpath "$1")
output_dir=$(realpath -m "$2")
output_parent=$(dirname "$output_dir")
[[ -f $vendor_image ]] || {
	echo "Vendor image not found: $vendor_image" >&2
	exit 1
}
[[ $(blkid -p -s LABEL -o value "$vendor_image") == vendor ]] || {
	echo "Input is not a filesystem labeled vendor: $vendor_image" >&2
	exit 1
}
[[ -d $output_parent ]] || {
	echo "Output parent does not exist: $output_parent" >&2
	exit 1
}
[[ ! -e $output_dir ]] || {
	echo "Refusing to overwrite existing output: $output_dir" >&2
	exit 1
}

mount_dir=$(mktemp -d /tmp/tb371fc-vendor-camera.XXXXXX)
staging_dir=$(mktemp -d "$output_parent/.tb371fc-camera-metadata.XXXXXX")
complete=0
cleanup() {
	set +e
	if mountpoint -q "$mount_dir"; then
		umount "$mount_dir"
	fi
	rmdir "$mount_dir"
	if [[ $complete -ne 1 ]]; then
		rm -rf -- "$staging_dir"
	fi
}
trap cleanup EXIT

mount -o loop,ro,noload "$vendor_image" "$mount_dir"

mapfile -d '' camera_files < <(
	find "$mount_dir/lib64/camera" -maxdepth 1 -type f \
		\( -name 'com.qti.sensor.AX6637_*.so' -o \
		-name 'com.qti.sensormodule.AX6637_*.bin' -o \
		-name 'com.qti.eeprom.*.so' \) -print0 | sort -z
)
[[ ${#camera_files[@]} -eq 11 ]] || {
	echo "Expected 11 AX6637 sensor/module/EEPROM files, found ${#camera_files[@]}." >&2
	exit 1
}

for source in "${camera_files[@]}"; do
	relative=${source#"$mount_dir/"}
	install -Dm0644 "$source" "$staging_dir/$relative"
done

for relative in \
	bin/init.dtab.camera.sh \
	bin/hw/android.hardware.camera.provider@2.4-service_64 \
	lib64/hw/camera.qcom.so; do
	install -Dm0644 "$mount_dir/$relative" "$staging_dir/$relative"
done

(
	cd "$staging_dir"
	find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum
) >"$staging_dir/SHA256SUMS"

umount "$mount_dir"
mv -T "$staging_dir" "$output_dir"
complete=1

echo "TB371FC stock camera metadata extracted read-only: $output_dir"
du -sh "$output_dir"
