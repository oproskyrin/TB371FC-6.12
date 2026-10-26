#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r79-post-memblock-zero-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r80-post-memblock-try-nid-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=498f6636980955726af8f637caf5cf5b7bcf09011b40f166daaddab1438c7942
zero_checkpoint_offset=$((0x019ddb10))
try_nid_return_offset=$((0x01a00a34))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$zero_checkpoint_offset" count=4 status=none | xxd -p)" = c89dff17
test "$(dd if="$base_image" bs=1 skip="$try_nid_return_offset" count=4 status=none | xxd -p)" = a00000b4

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore the original `mrs x8, sp_el0` after the allocation zero-fill.
printf '\x08\x41\x38\xd5' | dd of="$image" bs=1 seek="$zero_checkpoint_offset" conv=notrunc status=none
# In early_init_dt_alloc_memory_arch(), replace `cbz x0` immediately after
# memblock_alloc_try_nid() returns with b 0x019c5230. Raw Image offset
# 0x01a00a34 -> target 0x019c5230, encoding 0x17ff11ff.
printf '\xff\x11\xff\x17' | dd of="$image" bs=1 seek="$try_nid_return_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$zero_checkpoint_offset" count=4 status=none | xxd -p)" = 084138d5
test "$(dd if="$image" bs=1 skip="$try_nid_return_offset" count=4 status=none | xxd -p)" = ff11ff17
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r80 layout-preserving post-memblock-try-nid checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The r79 post-zero-fill checkpoint
is removed. Inside early_init_dt_alloc_memory_arch(), the instruction
immediately after memblock_alloc_try_nid() returns is replaced with a direct
branch to the already-audited PSCI reset trampoline.

Automatic reset proves the complete memblock_alloc_try_nid() call returned.
No reset localizes the hang to its post-memset stack-protector/return epilogue.
This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
