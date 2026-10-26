#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
set -euo pipefail

if (( $# != 5 )); then
	echo "Usage: $0 UNPACK_BOOTIMG_PY BOOT_IMG IMAGE INITRAMFS DTB" >&2
	exit 2
fi

unpack_bootimg=$(realpath "$1")
boot_img=$(realpath "$2")
kernel=$(realpath "$3")
initramfs=$(realpath "$4")
dtb=$(realpath "$5")
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

info=$(python3 "$unpack_bootimg" --boot_img "$boot_img" --out "$stage" \
	--format info)
printf '%s\n' "$info"

grep -q '^boot magic: ANDROID!$' <<<"$info"
grep -q '^boot image header version: 2$' <<<"$info"
cmp "$kernel" "$stage/kernel"
cmp "$initramfs" "$stage/ramdisk"
cmp "$dtb" "$stage/dtb"
gzip -t "$initramfs"

archive_list="$stage/initramfs.list"
gzip -dc "$initramfs" | cpio -it 2>/dev/null >"$archive_list"
for required in \
	init \
	bin/input-monitor \
	bin/setup-usb-console \
	bin/ip \
	bin/udhcpc \
	bin/lsusb \
	usr/lib/firmware/lenovo/tb371fc/novatek_ts_fw_boe_6.bin \
	usr/lib/firmware/lenovo/tb371fc/novatek_ts_tm_fw_6.bin; do
	grep -Fxq "$required" "$archive_list"
done
grep -Eq '^usr/lib/modules/.*/nt36523_ts\.ko$' "$archive_list"
grep -Eq '^usr/lib/modules/.*/libcomposite\.ko$' "$archive_list"
grep -Eq '^usr/lib/modules/.*/u_serial\.ko$' "$archive_list"
grep -Eq '^usr/lib/modules/.*/usb_f_acm\.ko$' "$archive_list"
grep -Eq '^usr/lib/modules/.*/r8152\.ko$' "$archive_list"
grep -Eq '^usr/lib/modules/.*/ax88179_178a\.ko$' "$archive_list"
grep -Eq '^usr/lib/modules/.*/cdc_ether\.ko$' "$archive_list"
grep -Eq '^usr/lib/modules/.*/usbnet\.ko$' "$archive_list"

max_size=$((96 * 1024 * 1024))
actual_size=$(stat -c %s "$boot_img")
if (( actual_size > max_size )); then
	echo "Boot image exceeds the stock 96 MiB limit" >&2
	exit 1
fi

echo "Verified boot image components are byte-identical."
printf 'Size: %d bytes (limit: %d)\n' "$actual_size" "$max_size"
sha256sum "$boot_img" "$kernel" "$initramfs" "$dtb"
