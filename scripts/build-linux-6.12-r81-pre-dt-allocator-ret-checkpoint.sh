#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r80-post-memblock-try-nid-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r81-pre-dt-allocator-ret-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=aef75194e5138758dfcb00b05c60b6c0f4e866f42f53579f7d7aa16769729211
try_nid_checkpoint_offset=$((0x01a00a34))
allocator_ret_offset=$((0x01a00a44))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$try_nid_checkpoint_offset" count=4 status=none | xxd -p)" = ff11ff17
test "$(dd if="$base_image" bs=1 skip="$allocator_ret_offset" count=4 status=none | xxd -p)" = c0035fd6

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore the original `cbz x0` after memblock_alloc_try_nid().
printf '\xa0\x00\x00\xb4' | dd of="$image" bs=1 seek="$try_nid_checkpoint_offset" conv=notrunc status=none
# Replace the successful-path `ret` in early_init_dt_alloc_memory_arch(),
# after ldp/autiasp, with b 0x019c5230. Raw Image offset 0x01a00a44 ->
# target 0x019c5230, encoding 0x17ff11fb.
printf '\xfb\x11\xff\x17' | dd of="$image" bs=1 seek="$allocator_ret_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$try_nid_checkpoint_offset" count=4 status=none | xxd -p)" = a00000b4
test "$(dd if="$image" bs=1 skip="$allocator_ret_offset" count=4 status=none | xxd -p)" = fb11ff17
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r81 layout-preserving pre-DT-allocator-ret checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The r80 checkpoint after
memblock_alloc_try_nid() is removed. The successful-path ret in
early_init_dt_alloc_memory_arch(), after its ldp/autiasp epilogue, is replaced
with a direct branch to the already-audited PSCI reset trampoline.

Automatic reset proves the allocator reaches its final ret instruction. Since
r77 did not reach the caller, that result would isolate the fault to the
actual authenticated return/control transfer. This is a diagnostic candidate,
not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
