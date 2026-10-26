#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r73-post-unflatten-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r74-post-rmem-scan-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=f20b414abaa1f60d1ab61e56e6d2d3d56f568b529ba150db8d6fe10d167cd93c
setup_trigger_offset=$((0x019c5268))
rmem_return_offset=$((0x01a00900))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$setup_trigger_offset" count=4 status=none | xxd -p)" = f2ffff17
test "$(dd if="$base_image" bs=1 skip="$rmem_return_offset" count=4 status=none | xxd -p)" = 130200b4

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore r70's original bootmem_init() call in setup_arch.
printf '\xc7\x14\x00\x94' | dd of="$image" bs=1 seek="$setup_trigger_offset" conv=notrunc status=none
# In unflatten_device_tree(), replace cbz x19 after
# fdt_scan_reserved_mem_reg_nodes() with b 0x019c5230.
# Current 0x01a00900 -> target 0x019c5230, encoding 0x17ff124c.
printf '\x4c\x12\xff\x17' | dd of="$image" bs=1 seek="$rmem_return_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$setup_trigger_offset" count=4 status=none | xxd -p)" = c7140094
test "$(dd if="$image" bs=1 skip="$rmem_return_offset" count=4 status=none | xxd -p)" = 4c12ff17
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r74 layout-preserving post-reserved-memory-scan checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The setup_arch bootmem_init() call
is restored. Inside unflatten_device_tree(), the instruction immediately after
fdt_scan_reserved_mem_reg_nodes() returns is replaced with a direct branch to
the already-audited PSCI reset trampoline.

Automatic reset proves the reserved-memory flat-DT scan returned. No reset
localizes the hang inside fdt_scan_reserved_mem_reg_nodes(). This is a
diagnostic candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
