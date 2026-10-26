#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r72-post-bootmem-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r73-post-unflatten-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=11ef7ffb0a4335c8b742ab75a2b6f96da5e5695f0ef1f8ab2ea88c2124d38bff
old_trigger_offset=$((0x019c526c))
new_trigger_offset=$((0x019c5268))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$old_trigger_offset" count=4 status=none | xxd -p)" = f1ffff17
test "$(dd if="$base_image" bs=1 skip="$new_trigger_offset" count=4 status=none | xxd -p)" = c7140094

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore r70's original request_standard_resources() call at 0x526c.
printf '\x9a\x00\x00\x94' | dd of="$image" bs=1 seek="$old_trigger_offset" conv=notrunc status=none
# Replace bl bootmem_init at 0x5268 with b 0x5230.
# Delta = -0x38 bytes = -14 instructions: encoding 0x17fffff2.
printf '\xf2\xff\xff\x17' | dd of="$image" bs=1 seek="$new_trigger_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$old_trigger_offset" count=4 status=none | xxd -p)" = 9a000094
test "$(dd if="$image" bs=1 skip="$new_trigger_offset" count=4 status=none | xxd -p)" = f2ffff17
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r73 layout-preserving post-unflatten checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. Relative to r72, the
request_standard_resources() call at Image offset 0x019c526c is restored and
the bootmem_init() call at 0x019c5268 is replaced with a branch to the
already-audited PSCI reset trampoline at 0x019c5230.

An automatic reset proves unflatten_device_tree() returned and localizes the
r72 failure to bootmem_init(). No reset with the stage-30 stripe localizes the
failure to unflatten_device_tree(). This is a diagnostic candidate.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
