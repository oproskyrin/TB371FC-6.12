#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r76-post-unflatten-sizing-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r77-post-unflatten-allocation-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=0886498b6cc80ed999e4777a2ec84ccfdb816a0a9f91d799c129bc364f964885
sizing_checkpoint_offset=$((0x00c66ba4))
allocation_return_offset=$((0x00c66bd4))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$sizing_checkpoint_offset" count=4 status=none | xxd -p)" = a3793514
test "$(dd if="$base_image" bs=1 skip="$allocation_return_offset" count=4 status=none | xxd -p)" = f60300aa

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore the original `cmp w0, #1` after the sizing-only traversal.
printf '\x1f\x04\x00\x71' | dd of="$image" bs=1 seek="$sizing_checkpoint_offset" conv=notrunc status=none
# Replace `mov x22, x0` immediately after the DT allocator callback returns
# with b 0x019c5230. Raw Image offset 0x00c66bd4 -> target 0x019c5230,
# encoding 0x14357997.
printf '\x97\x79\x35\x14' | dd of="$image" bs=1 seek="$allocation_return_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$sizing_checkpoint_offset" count=4 status=none | xxd -p)" = 1f040071
test "$(dd if="$image" bs=1 skip="$allocation_return_offset" count=4 status=none | xxd -p)" = 97793514
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r77 layout-preserving post-unflatten-allocation checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The r76 sizing checkpoint is
removed. Inside __unflatten_device_tree(), the instruction immediately after
the DT allocator callback returns is replaced with a direct branch to the
already-audited PSCI reset trampoline.

Automatic reset proves the allocation callback returned. No reset localizes
the hang to size handling or early_init_dt_alloc_memory_arch()/memblock_alloc().
This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
