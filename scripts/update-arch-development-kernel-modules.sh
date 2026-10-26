#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

if (( $# != 2 )); then
	echo "Usage: $0 DEVELOPMENT_IMAGE KERNEL_MODULES_ARCHIVE" >&2
	exit 2
fi
[[ $EUID == 0 ]] || { echo 'Run as root.' >&2; exit 1; }

image=$(realpath "$1")
archive=$(realpath "$2")
release=7.1.8-tb371fc
gib=$((1024 * 1024 * 1024))
image_size=$(stat -c %s "$image")
(( image_size >= 12 * gib && image_size <= 64 * gib && image_size % gib == 0 )) || {
	echo "Refusing unexpected development image size: $image_size" >&2
	exit 1
}
[[ -s $archive ]]

mapfile -t archive_entries < <(tar -tzf "$archive")
(( ${#archive_entries[@]} >= 1000 )) || {
	echo 'Kernel modules archive has too few entries.' >&2
	exit 1
}
for entry in "${archive_entries[@]}"; do
	case "$entry" in
		lib/modules/|"lib/modules/$release/"|"lib/modules/$release/"*) ;;
		*)
			echo "Unsafe or unexpected archive entry: $entry" >&2
			exit 1
			;;
	esac
	[[ $entry != /* && $entry != '..' && $entry != '../'* && $entry != *'/../'* && $entry != *'/..' ]] || {
		echo "Unsafe or unexpected archive entry: $entry" >&2
		exit 1
	}
done

e2fsck -fn "$image" >/dev/null
mount_dir=$(mktemp -d)
backup=$(mktemp --suffix=.tar.gz)
mounted=0
updated=0
committed=0
cleanup() {
	if (( mounted )) && mountpoint -q "$mount_dir"; then
		if (( updated && !committed )); then
			rm -rf -- "$mount_dir/lib/modules/$release"
			tar -xzf "$backup" -C "$mount_dir"
			sync
		fi
		umount "$mount_dir" || true
	fi
	rm -f -- "$backup"
	rmdir "$mount_dir" 2>/dev/null || true
}
trap cleanup EXIT

mount -o loop,rw "$image" "$mount_dir"
mounted=1
grep -qx 'schema=2' "$mount_dir/etc/tb371fc-development-image"
grep -qx 'platform=Lenovo TB371FC' "$mount_dir/etc/tb371fc-development-image"
[[ -d $mount_dir/lib/modules/$release ]]
[[ -s $mount_dir/usr/share/tb371fc-development-kernel-modules.txt ]]

tar -C "$mount_dir" -czf "$backup" \
	"lib/modules/$release" \
	usr/share/tb371fc-development-kernel-modules.txt

module_root=$(realpath "$mount_dir/lib/modules")
module_dir=$(realpath "$mount_dir/lib/modules/$release")
[[ $module_root == "$mount_dir/"* ]]
[[ $module_dir == "$module_root/$release" ]]
updated=1
rm -rf -- "$module_dir"
tar -xzf "$archive" -C "$mount_dir"

module_count=$(find "$module_dir" -type f -name '*.ko*' | wc -l)
[[ $module_count == 1510 ]] || {
	echo "Unexpected installed module count: $module_count" >&2
	exit 1
}
depmod -b "$mount_dir" "$release"
printf '%s\n' \
	"kernel_release=$release" \
	"archive_sha256=$(sha256sum "$archive" | awk '{print $1}')" \
	"module_files=$module_count" \
	>"$mount_dir/usr/share/tb371fc-development-kernel-modules.txt"

sync
committed=1
umount "$mount_dir"
mounted=0
e2fsck -fy "$image" >/dev/null
sha256sum "$image"
