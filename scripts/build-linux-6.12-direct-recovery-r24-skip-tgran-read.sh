#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

project="$(cd "$(dirname "$0")/.." && pwd)"
source_package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-arch612-mmu-diag+-desktop-mmu-diag-r1
output=${OUTPUT:-/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-direct-recovery-r24-skip-tgran-read}
patched_package=$(mktemp -d /tmp/tb371fc-r24-package.XXXXXX)
trap 'rm -rf -- "$patched_package"' EXIT

test ! -e "$output" || { echo "Refusing to overwrite $output" >&2; exit 1; }
cp -a "$source_package/." "$patched_package/"

# r23 still stopped at stage 0x47 after its diagnostic dsb was removed.  The
# next instruction is the ID_AA64MMFR0_EL1 read.  Bypass the complete TGran4
# diagnostic block and continue at the stage-0x48 marker.  The SM8250 stock
# kernel already proves 4 KiB granule support.
python3 - "$patched_package/Image" <<'PY'
from pathlib import Path
import sys

image = Path(sys.argv[1])
data = bytearray(image.read_bytes())
patches = {
    0x19ab7b0: (bytes.fromhex('9f3f03d5'), bytes.fromhex('1f2003d5')),
    0x19ab7b4: (bytes.fromhex('030738d5'), bytes.fromhex('06000014')),
}
for offset, (old, new) in patches.items():
    actual = bytes(data[offset:offset + 4])
    if actual != old:
        raise SystemExit(f'unexpected bytes at {offset:#x}: {actual.hex()} != {old.hex()}')
    data[offset:offset + 4] = new
image.write_bytes(data)
PY

test "$(dd if="$patched_package/Image" bs=1 skip=$((0x19ab7b0)) count=4 status=none | xxd -p)" = 1f2003d5
test "$(dd if="$patched_package/Image" bs=1 skip=$((0x19ab7b4)) count=4 status=none | xxd -p)" = 06000014

export PACKAGE="$patched_package"
export OUTPUT="$output"
export BUILD_LABEL="${BUILD_LABEL:-r24 minimal handoff; bypass TGran4 system-register read}"
export EXTRA_CFLAGS="${EXTRA_CFLAGS:--DSKIP_CACHE_MAINTENANCE=1 -DSKIP_HANDOFF_BARRIERS=1 -DDIRECT_BRANCH_AFTER_BLUE=1}"
exec "$project/scripts/build-linux-6.12-direct-recovery-r17-proven-v56-wrapper.sh"
