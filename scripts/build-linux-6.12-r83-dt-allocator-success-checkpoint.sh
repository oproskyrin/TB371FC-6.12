#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r82-pre-dt-allocator-autiasp-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r83-dt-allocator-success-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=425cce7b542320065e5c8622629aa02853003ea8100b5ff7e6b6bbce40aff2c1
success_path_offset=$((0x01a00a38))
autiasp_checkpoint_offset=$((0x01a00a40))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$success_path_offset" count=4 status=none | xxd -p)" = f44f41a9
test "$(dd if="$base_image" bs=1 skip="$autiasp_checkpoint_offset" count=4 status=none | xxd -p)" = fc11ff17

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore the original `autiasp` from r81/r79.
printf '\xbf\x23\x03\xd5' | dd of="$image" bs=1 seek="$autiasp_checkpoint_offset" conv=notrunc status=none
# Keep the original `cbz x0, failure` intact. Replace the first instruction
# reached only when x0 != NULL (`ldp x20, x19, [sp, #16]`) with a branch to
# the audited PSCI reset trampoline. Raw Image 0x01a00a38 -> 0x019c5230.
printf '\xfe\x11\xff\x17' | dd of="$image" bs=1 seek="$success_path_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$success_path_offset" count=4 status=none | xxd -p)" = fe11ff17
test "$(dd if="$image" bs=1 skip="$autiasp_checkpoint_offset" count=4 status=none | xxd -p)" = bf2303d5
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r83 layout-preserving DT allocator success checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The r82 autiasp checkpoint is
removed. The original cbz x0 failure test remains intact. The first
instruction reached only when memblock_alloc() returns a non-NULL pointer is
replaced with a direct branch to the audited PSCI reset trampoline.

Automatic reset proves successful allocation. No reset, together with r80
proving execution reached the cbz instruction, proves memblock_alloc() returned
NULL and entered the panic path. This corrects the ambiguity in r78-r80.
This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
