#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

artifact_dir=${1:-/mnt/d/TB371FC-builds/abl-entry-probe-v1}
unpack_bootimg=${UNPACK_BOOTIMG:-/root/mkbootimg/unpack_bootimg.py}
avbtool=${AVBTOOL:-/root/avb/avbtool.py}
probe="$artifact_dir/abl-entry-probe.bin"
image="$artifact_dir/tb371fc-abl-entry-probe-v1-recovery.img"
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT

for input in "$probe" "$image" "$artifact_dir/SHA256SUMS" \
	"$artifact_dir/HARDWARE-STATUS.txt" "$artifact_dir/TEST-INSTRUCTIONS.txt"; do
	[[ -s $input ]] || { echo "Missing input: $input" >&2; exit 1; }
done
(cd "$artifact_dir" && sha256sum -c SHA256SUMS)
grep -qx 'Hardware status: OFFLINE ONLY; NOT FLASHED' "$artifact_dir/HARDWARE-STATUS.txt"
[[ $(stat -c %s "$probe") -eq 4096 ]]
[[ $(stat -c %s "$image") -eq $((100 * 1024 * 1024)) ]]

python3 - "$probe" <<'PY'
import struct
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
code0, code1 = struct.unpack_from("<II", data, 0)
text_offset, image_size, flags = struct.unpack_from("<QQQ", data, 8)
reserved = struct.unpack_from("<QQQ", data, 32)
assert code0 & 0xfc000000 == 0x14000000
assert code1 == 0
assert text_offset == 0x80000
assert image_size == len(data) == 4096
assert flags == 0xA
assert reserved == (0, 0, 0)
assert data[56:60] == b"ARM\x64"
assert b"ANDROID!" not in data
print(f"ARM64 entry probe verified: branch={code0:#010x}, size={len(data)}")
PY

python3 "$unpack_bootimg" --boot_img "$image" --out "$stage/unpacked" --format info \
	>"$stage/info.txt"
grep -q '^boot image header version: 2$' "$stage/info.txt"
grep -q '^kernel load address: 0x00008000$' "$stage/info.txt"
grep -q '^ramdisk size: 21840789$' "$stage/info.txt"
grep -q '^recovery dtbo size: 4299995$' "$stage/info.txt"
grep -q '^dtb size: 1609710$' "$stage/info.txt"
cmp "$stage/unpacked/kernel" "$probe"
python3 "$avbtool" info_image --image "$image" >"$stage/avb-info.txt"
grep -q 'Hash descriptor:' "$stage/avb-info.txt"
grep -q 'Partition Name:.*recovery$' "$stage/avb-info.txt"

echo 'TB371FC ABL entry probe is offline-verified.'

