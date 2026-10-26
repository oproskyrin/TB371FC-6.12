#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r71-post-early-ioremap-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r72-post-bootmem-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=3b243f8d55d2b801ed865adbe5b30dd803f0a5cd09ddc598a4bd41a04abd0f02
old_trigger_offset=$((0x019c5274))
new_trigger_offset=$((0x019c526c))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$old_trigger_offset" count=4 status=none | xxd -p)" = efffff17
test "$(dd if="$base_image" bs=1 skip="$new_trigger_offset" count=4 status=none | xxd -p)" = 9a000094

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore r70's original psci_dt_init() call at 0x5274.
printf '\x03\xe0\x00\x94' | dd of="$image" bs=1 seek="$old_trigger_offset" conv=notrunc status=none
# Replace bl request_standard_resources at 0x526c with b 0x5230.
# Delta = -0x3c bytes = -15 instructions: encoding 0x17fffff1.
printf '\xf1\xff\xff\x17' | dd of="$image" bs=1 seek="$new_trigger_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$old_trigger_offset" count=4 status=none | xxd -p)" = 03e00094
test "$(dd if="$image" bs=1 skip="$new_trigger_offset" count=4 status=none | xxd -p)" = f1ffff17
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r72 layout-preserving post-bootmem checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. Relative to r71, the psci_dt_init()
call at Image offset 0x019c5274 is restored and the
request_standard_resources() call at 0x019c526c is replaced with a branch to
the already-audited PSCI reset trampoline at 0x019c5230.

An automatic reset proves unflatten_device_tree() and bootmem_init() returned.
No reset with the stage-30 stripe localizes the hang to one of those two calls.
This is a diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
