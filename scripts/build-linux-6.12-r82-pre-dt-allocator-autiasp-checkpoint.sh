#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r81-pre-dt-allocator-ret-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r82-pre-dt-allocator-autiasp-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=5caba6e943ffabc4ee82df047959b1e41f9ad7103d78d3f52227a3e2c2acd2a2
allocator_autiasp_offset=$((0x01a00a40))
allocator_ret_checkpoint_offset=$((0x01a00a44))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$allocator_autiasp_offset" count=4 status=none | xxd -p)" = bf2303d5
test "$(dd if="$base_image" bs=1 skip="$allocator_ret_checkpoint_offset" count=4 status=none | xxd -p)" = fb11ff17

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore the original successful-path `ret`.
printf '\xc0\x03\x5f\xd6' | dd of="$image" bs=1 seek="$allocator_ret_checkpoint_offset" conv=notrunc status=none
# Replace `autiasp`, after both stack restores and immediately before ret, with
# b 0x019c5230. Raw Image offset 0x01a00a40 -> target 0x019c5230,
# encoding 0x17ff11fc.
printf '\xfc\x11\xff\x17' | dd of="$image" bs=1 seek="$allocator_autiasp_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$allocator_autiasp_offset" count=4 status=none | xxd -p)" = fc11ff17
test "$(dd if="$image" bs=1 skip="$allocator_ret_checkpoint_offset" count=4 status=none | xxd -p)" = c0035fd6
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r82 layout-preserving pre-DT-allocator-autiasp checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The r81 ret checkpoint is removed.
The successful-path autiasp in early_init_dt_alloc_memory_arch(), after both
stack restores and immediately before ret, is replaced with a direct branch
to the already-audited PSCI reset trampoline.

Automatic reset proves both stack-load instructions completed and localizes
r81 to autiasp itself. No reset localizes the fault to the stack restores.
This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
