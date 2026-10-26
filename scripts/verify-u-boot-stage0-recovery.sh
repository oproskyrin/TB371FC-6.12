#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

artifact_dir=${1:-/mnt/d/TB371FC-builds/u-boot-tb371fc-stage0}
unpack_bootimg=${UNPACK_BOOTIMG:-/root/mkbootimg/unpack_bootimg.py}
avbtool=${AVBTOOL:-/root/avb/avbtool.py}
image="$artifact_dir/tb371fc-u-boot-stage0-recovery.img"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

for input in "$image" "$artifact_dir/RECOVERY-SHA256SUMS" \
	"$artifact_dir/RECOVERY-STATUS.txt" "$unpack_bootimg" "$avbtool"; do
	[[ -s $input ]] || { echo "Missing verification input: $input" >&2; exit 1; }
done

[[ $(stat -c %s "$image") -eq $((100 * 1024 * 1024)) ]]
(cd "$artifact_dir" && sha256sum -c RECOVERY-SHA256SUMS)
grep -q '^Hardware status: OFFLINE ONLY; NOT FLASHED$' \
	"$artifact_dir/RECOVERY-STATUS.txt"

python3 "$unpack_bootimg" --boot_img "$image" --out "$stage/unpacked" --format info \
	>"$stage/info.txt"
grep -q '^boot image header version: 2$' "$stage/info.txt"
grep -q '^page size: 4096$' "$stage/info.txt"
grep -q '^kernel load address: 0x00008000$' "$stage/info.txt"
grep -q '^ramdisk size: 0$' "$stage/info.txt"
grep -q '^recovery dtbo size: 4299963$' "$stage/info.txt"
grep -q '^dtb address: 0x0000000001f00000$' "$stage/info.txt"

cmp "$stage/unpacked/kernel" "$artifact_dir/u-boot-nodtb.bin"
cmp "$stage/unpacked/dtb" "$artifact_dir/sm8250-lenovo-tb371fc-u-boot.dtb"
python3 "$avbtool" info_image --image "$image" >"$stage/avb-info.txt"
grep -q 'Hash descriptor:' "$stage/avb-info.txt"
grep -q 'Partition Name:.*recovery$' "$stage/avb-info.txt"

echo "TB371FC U-Boot stage-0 recovery image verified (offline only)."
