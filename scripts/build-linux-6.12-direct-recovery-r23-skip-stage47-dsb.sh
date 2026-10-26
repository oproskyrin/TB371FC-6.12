#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
source_package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-mmu-diag+-desktop-mmu-diag-r1
output=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r23-skip-stage47-dsb
patched_package=$(mktemp -d /tmp/tb371fc-r23-package.XXXXXX)
trap 'rm -rf -- "$patched_package"' EXIT

test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }
cp -a "$source_package/." "$patched_package/"

# Keep the two proven TGran4 rejection fixes from r20.  r22 reached stage
# 0x47 and then stopped at the diagnostic-only dsb sy before the feature
# read, so NOP only that barrier.  Architectural barriers around TTBR/SCTLR
# remain untouched.
python3 - "$patched_package/Image" <<'PY'
from pathlib import Path
import sys

image = Path(sys.argv[1])
data = bytearray(image.read_bytes())
patches = {
    0x19ab7b0: (bytes.fromhex('9f3f03d5'), bytes.fromhex('1f2003d5')),
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

for offset in 0x19ab7b0 0x19ab7c0 0x19ab7c8; do
    test "$(dd if="$patched_package/Image" bs=1 skip=$((offset)) count=4 status=none | xxd -p)" = 1f2003d5
done

export PACKAGE="$patched_package"
export OUTPUT="$output"
export BUILD_LABEL='r23 minimal handoff; skip diagnostic stage47 dsb; TGran4 fixes'
export EXTRA_CFLAGS='-DSKIP_CACHE_MAINTENANCE=1 -DSKIP_HANDOFF_BARRIERS=1 -DDIRECT_BRANCH_AFTER_BLUE=1'
exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
