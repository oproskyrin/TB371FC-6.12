#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r78-post-memblock-internal-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r79-post-memblock-zero-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=c33199d70f18a56c114e9fe6e813b68b887b0fadf836392b871646253eb82b7f
internal_checkpoint_offset=$((0x019ddaf8))
zero_return_offset=$((0x019ddb10))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$internal_checkpoint_offset" count=4 status=none | xxd -p)" = ce9dff17
test "$(dd if="$base_image" bs=1 skip="$zero_return_offset" count=4 status=none | xxd -p)" = 084138d5

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore the original `mov x20, x0` after memblock_alloc_internal().
printf '\xf4\x03\x00\xaa' | dd of="$image" bs=1 seek="$internal_checkpoint_offset" conv=notrunc status=none
# Replace the instruction immediately after memblock_alloc_try_nid() returns
# from its allocation-clearing __memset with b 0x019c5230. Raw Image offset
# 0x019ddb10 -> target 0x019c5230, encoding 0x17ff9dc8.
printf '\xc8\x9d\xff\x17' | dd of="$image" bs=1 seek="$zero_return_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$internal_checkpoint_offset" count=4 status=none | xxd -p)" = f40300aa
test "$(dd if="$image" bs=1 skip="$zero_return_offset" count=4 status=none | xxd -p)" = c89dff17
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r79 layout-preserving post-memblock-zero checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The r78 checkpoint after
memblock_alloc_internal() is removed. Inside memblock_alloc_try_nid(), the
instruction immediately after the allocation-clearing __memset returns is
replaced with a direct branch to the already-audited PSCI reset trampoline.

Automatic reset proves the zero-fill returned. No reset localizes the hang to
that __memset, strongly indicating an invalid or unmapped allocated virtual
address. This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
