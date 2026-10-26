#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r74-post-rmem-scan-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r75-post-core-unflatten-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=dd41ccccb13526e40e0bd1bef1278786808c3635a865b84974a3d99cbe0019b0
rmem_return_offset=$((0x01a00900))
unflatten_return_offset=$((0x01a00928))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$rmem_return_offset" count=4 status=none | xxd -p)" = 4c12ff17
test "$(dd if="$base_image" bs=1 skip="$unflatten_return_offset" count=4 status=none | xxd -p)" = e00314aa

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore r70's original `cbz x19, ...` after reserved-memory scanning.
printf '\x13\x02\x00\xb4' | dd of="$image" bs=1 seek="$rmem_return_offset" conv=notrunc status=none
# Replace `mov x0, x20` immediately after __unflatten_device_tree() returns
# with a direct branch to the audited PSCI reset trampoline at 0x019c5230.
# Current 0x01a00928 -> target 0x019c5230, encoding 0x17ff1242.
printf '\x42\x12\xff\x17' | dd of="$image" bs=1 seek="$unflatten_return_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$rmem_return_offset" count=4 status=none | xxd -p)" = 130200b4
test "$(dd if="$image" bs=1 skip="$unflatten_return_offset" count=4 status=none | xxd -p)" = 4212ff17
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r75 layout-preserving post-core-unflatten checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The r74 checkpoint after
fdt_scan_reserved_mem_reg_nodes() is removed by restoring its original cbz.
Inside unflatten_device_tree(), the first instruction immediately after
__unflatten_device_tree() returns is replaced with a direct branch to the
already-audited PSCI reset trampoline.

Automatic reset proves __unflatten_device_tree() returned and localizes the
r73 failure to of_alias_scan(). No reset localizes the hang inside
__unflatten_device_tree(). This is a diagnostic candidate.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
