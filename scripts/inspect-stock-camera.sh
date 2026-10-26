#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
set -euo pipefail

if [[ $# -ne 2 ]]; then
	echo "Usage: $0 VENDOR_EXT4_IMAGE ODM_EXT4_IMAGE" >&2
	exit 2
fi
[[ $EUID -eq 0 ]] || {
	echo "Run as root; images are mounted read-only through temporary loop devices." >&2
	exit 1
}

vendor_image=$(realpath "$1")
odm_image=$(realpath "$2")
for image in "$vendor_image" "$odm_image"; do
	[[ -f $image ]] || {
		echo "Image not found: $image" >&2
		exit 1
	}
done

vendor_label=$(blkid -p -s LABEL -o value "$vendor_image")
odm_label=$(blkid -p -s LABEL -o value "$odm_image")
[[ $vendor_label == vendor ]] || {
	echo "Expected vendor filesystem label, found: $vendor_label" >&2
	exit 1
}
[[ $odm_label == odm ]] || {
	echo "Expected odm filesystem label, found: $odm_label" >&2
	exit 1
}

mount_root=$(mktemp -d /tmp/tb371fc-stock-camera.XXXXXX)
vendor_mount="$mount_root/vendor"
odm_mount="$mount_root/odm"
mkdir "$vendor_mount" "$odm_mount"
cleanup() {
	set +e
	if mountpoint -q "$odm_mount"; then
		umount "$odm_mount"
	fi
	if mountpoint -q "$vendor_mount"; then
		umount "$vendor_mount"
	fi
	rmdir "$odm_mount" "$vendor_mount" "$mount_root"
}
trap cleanup EXIT

mount -o loop,ro,noload "$vendor_image" "$vendor_mount"
mount -o loop,ro,noload "$odm_image" "$odm_mount"

echo "TB371FC stock camera-related files"
echo "vendor_image=$vendor_image"
echo "odm_image=$odm_image"
echo

for partition in vendor odm; do
	if [[ $partition == vendor ]]; then
		partition_root=$vendor_mount
	else
		partition_root=$odm_mount
	fi
	echo "== $partition =="
	find "$partition_root" -type f \
		\( -iname '*camera*' -o -iname '*camx*' -o -iname '*sensor*' -o \
		-iname '*chromatix*' -o -iname '*eeprom*' -o -iname '*actuator*' \) \
		-printf "$partition/%P\n" | sort
	done
