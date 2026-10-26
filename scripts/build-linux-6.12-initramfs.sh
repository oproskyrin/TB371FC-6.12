#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

profile=${1:-safe}
base_initramfs=${BASE_INITRAMFS:-/mnt/d/TB371FC-builds/linux-7.1.8-tb371fc-r7-kexec-ram-test/initramfs-7.1.8-r7-arch-development.cpio.gz}
output=${OUTPUT_INITRAMFS:-/mnt/d/TB371FC-builds/initramfs-6.12.30-tb371fc-${profile}-r1.cpio.gz}

case "$profile" in
	safe)
		module_archive=${MODULE_ARCHIVE:-/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-safe-r2/modules-6.12.30-tb371fc-arch612-safe+.tar.gz}
		kernel_release=6.12.30-tb371fc-arch612-safe+
		;;
	desktop)
		module_archive=${MODULE_ARCHIVE:-/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-desktop-r2/modules-6.12.30-tb371fc-arch612-desktop+.tar.gz}
		kernel_release=6.12.30-tb371fc-arch612-desktop+
		;;
	*) echo "Usage: $0 [safe|desktop]" >&2; exit 2 ;;
esac

test -s "$base_initramfs"
test -s "$module_archive"
test ! -e "$output" || {
	echo "Refusing to overwrite: $output" >&2
	exit 1
}

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/unpack" "$work/overlay/usr/lib" "$work/overlay/etc"
tar -xzf "$module_archive" -C "$work/unpack"
test -d "$work/unpack/lib/modules/$kernel_release"
cp -a "$work/unpack/lib/modules" "$work/overlay/usr/lib/"
printf '%s\n' \
	"kernel_release=$kernel_release" \
	"profile=$profile" \
	'base=verified Arch development rescue initramfs' \
	>"$work/overlay/etc/tb371fc-linux-6.12-initramfs"

(
	cd "$work/overlay"
	find . -print0 | LC_ALL=C sort -z | \
		cpio --null -o --format=newc --owner=0:0 --quiet \
		>"$work/modules-overlay.cpio"
)

gzip -dc "$base_initramfs" >"$work/combined.cpio"
dd if="$work/modules-overlay.cpio" of="$work/combined.cpio" \
	oflag=append conv=notrunc status=none
gzip -n -9 -c "$work/combined.cpio" >"$output"
gzip -t "$output"

# The first archive must still provide PID 1. The appended archive must carry
# modules matching the kernel release; inspect both components independently
# because GNU cpio stops listing at the first TRAILER!!! record.
gzip -dc "$output" | cpio -it --quiet 2>/dev/null | \
	awk '$0 == "init" { found = 1 } END { exit !found }'
cpio -it --quiet <"$work/modules-overlay.cpio" | \
	awk -v release="$kernel_release" \
	'$0 == "usr/lib/modules/" release { found = 1 } END { exit !found }'

sha256sum "$base_initramfs" "$module_archive" "$output"
