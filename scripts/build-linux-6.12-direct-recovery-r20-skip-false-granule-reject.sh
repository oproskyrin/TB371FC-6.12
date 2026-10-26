#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
source_package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-mmu-diag+-desktop-mmu-diag-r1
output=${OUTPUT:-/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r20-skip-false-granule-reject}
patched_package=$(mktemp -d /tmp/tb371fc-r20-package.XXXXXX)
trap 'rm -rf -- "$patched_package"' EXIT

test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }
cp -a "$source_package/." "$patched_package/"

# __enable_mmu reads ID_AA64MMFR0_EL1.TGran4 and the diagnostic r19 image
# stops before stage 0x48.  SM8250 demonstrably runs a 4 KiB Android kernel,
# so retain the feature read but NOP only its two false rejection branches.
python3 - "$patched_package/Image" <<'PY'
from pathlib import Path
import sys

image = Path(sys.argv[1])
data = bytearray(image.read_bytes())
patches = {
    0x19ab7c0: (bytes.fromhex('cb0a0054'), bytes.fromhex('1f2003d5')),
    0x19ab7c8: (bytes.fromhex('8c0a0054'), bytes.fromhex('1f2003d5')),
}
for offset, (old, new) in patches.items():
    actual = bytes(data[offset:offset + 4])
    if actual != old:
        raise SystemExit(f'unexpected bytes at {offset:#x}: {actual.hex()} != {old.hex()}')
    data[offset:offset + 4] = new
image.write_bytes(data)
PY

test "$(stat -c %s "$patched_package/Image")" = 29401096
test "$(dd if="$patched_package/Image" bs=1 skip=$((0x19ab7c0)) count=4 status=none | xxd -p)" = 1f2003d5
test "$(dd if="$patched_package/Image" bs=1 skip=$((0x19ab7c8)) count=4 status=none | xxd -p)" = 1f2003d5

export PACKAGE="$patched_package"
export OUTPUT="$output"
export BUILD_LABEL="${BUILD_LABEL:-r20 proven r18 handoff; bypass false TGran4 rejection}"
export EXTRA_CFLAGS="${EXTRA_CFLAGS:--DSKIP_CACHE_MAINTENANCE=1}"
exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
