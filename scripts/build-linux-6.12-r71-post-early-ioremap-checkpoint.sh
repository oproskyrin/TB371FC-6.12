#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r70-embedded-pgtable-pool
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r71-post-early-ioremap-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=9644d29f837f0d52f7b25dcc19a4ea6b495833782810f2e6a933d74dacfd662f

# Raw Image offsets corresponding to setup_arch virtual addresses:
#   0x019c5224 -> ffff8000819c5224 (first old checkpoint instruction)
#   0x019c5230 -> ffff8000819c5230 (PSCI reset trampoline)
#   0x019c5238 -> ffff8000819c5238 (old r70 nop)
#   0x019c5274 -> ffff8000819c5274 (psci_dt_init call)
skip_offset=$((0x019c5224))
smc_offset=$((0x019c5238))
trigger_offset=$((0x019c5274))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$skip_offset" count=4 status=none | xxd -p)" = e1031faa
test "$(dd if="$base_image" bs=1 skip="$smc_offset" count=4 status=none | xxd -p)" = 1f2003d5
test "$(dd if="$base_image" bs=1 skip="$trigger_offset" count=4 status=none | xxd -p)" = 03e00094

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Preserve the complete r70 layout and reuse its dormant PSCI setup sequence.
#
# Normal path after arm64_memblock_init():
#   0x019c5224: b +0x18      -> skip the dormant reset trampoline
#
# Trampoline:
#   0x019c5230: mov  x0, #9
#   0x019c5234: movk x0, #0x8400, lsl #16
#   0x019c5238: smc  #0      -> PSCI SYSTEM_RESET
#
# Late checkpoint after early_ioremap_reset(), before psci_dt_init():
#   0x019c5274: b 0x019c5230
printf '\x06\x00\x00\x14' | dd of="$image" bs=1 seek="$skip_offset" conv=notrunc status=none
printf '\x03\x00\x00\xd4' | dd of="$image" bs=1 seek="$smc_offset" conv=notrunc status=none
printf '\xef\xff\xff\x17' | dd of="$image" bs=1 seek="$trigger_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$skip_offset" count=4 status=none | xxd -p)" = 06000014
test "$(dd if="$image" bs=1 skip="$smc_offset" count=4 status=none | xxd -p)" = 030000d4
test "$(dd if="$image" bs=1 skip="$trigger_offset" count=4 status=none | xxd -p)" = efffff17
test "$(cmp -l "$base_image" "$image" | wc -l)" = 12

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r71 layout-preserving late checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The complete r70/r68 Image layout
is retained. Three equal-size AArch64 instructions were replaced in place:

  0x019c5224  mov x1, xzr       -> b 0x019c523c
  0x019c5238  nop               -> smc #0
  0x019c5274  bl psci_dt_init   -> b 0x019c5230

The first branch skips the dormant reset sequence on the normal post-memblock
path. The second change restores its PSCI SYSTEM_RESET instruction. The final
branch invokes that sequence only after unflatten_device_tree(), bootmem_init(),
request_standard_resources(), and early_ioremap_reset() have all returned, and
before psci_dt_init() begins.

An automatic reset therefore proves that complete late setup_arch interval.
No reset after the visible stage-30 purple stripe localizes the hang to one of
those four calls. This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
