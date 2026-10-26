#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r77-post-unflatten-allocation-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r78-post-memblock-internal-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=139543061a8b40ccec49a9ed77561b048cb261cbe786f38131621b6b7fd18c6a
allocator_checkpoint_offset=$((0x00c66bd4))
memblock_internal_return_offset=$((0x019ddaf8))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$allocator_checkpoint_offset" count=4 status=none | xxd -p)" = 97793514
test "$(dd if="$base_image" bs=1 skip="$memblock_internal_return_offset" count=4 status=none | xxd -p)" = f40300aa

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore the original `mov x22, x0` after the outer DT allocator callback.
printf '\xf6\x03\x00\xaa' | dd of="$image" bs=1 seek="$allocator_checkpoint_offset" conv=notrunc status=none
# In memblock_alloc_try_nid(), replace `mov x20, x0` immediately after
# memblock_alloc_internal() returns with b 0x019c5230. Raw Image offset
# 0x019ddaf8 -> target 0x019c5230, encoding 0x17ff9dce.
printf '\xce\x9d\xff\x17' | dd of="$image" bs=1 seek="$memblock_internal_return_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$allocator_checkpoint_offset" count=4 status=none | xxd -p)" = f60300aa
test "$(dd if="$image" bs=1 skip="$memblock_internal_return_offset" count=4 status=none | xxd -p)" = ce9dff17
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r78 layout-preserving post-memblock-internal checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The r77 outer allocator checkpoint
is removed. Inside memblock_alloc_try_nid(), the instruction immediately after
memblock_alloc_internal() returns is replaced with a direct branch to the
already-audited PSCI reset trampoline.

Automatic reset proves memblock_alloc_internal() returned and localizes the
remaining fault to zeroing/epilogue after it. No reset localizes the hang
inside memblock_alloc_internal(). This is a diagnostic candidate, not a
release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
