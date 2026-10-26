#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r75-post-core-unflatten-checkpoint
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r76-post-unflatten-sizing-checkpoint
base_image=$base/Image
image=$package/Image
base_sha=3fb4fa1dba75fedca13083824bb57d018424928b86999cf62ed267334c0def2e
caller_checkpoint_offset=$((0x01a00928))
sizing_return_offset=$((0x00c66ba4))

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

test "$(dd if="$base_image" bs=1 skip="$caller_checkpoint_offset" count=4 status=none | xxd -p)" = 4212ff17
test "$(dd if="$base_image" bs=1 skip="$sizing_return_offset" count=4 status=none | xxd -p)" = 1f040071

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# Restore r70's original `mov x0, x20` after __unflatten_device_tree().
printf '\xe0\x03\x14\xaa' | dd of="$image" bs=1 seek="$caller_checkpoint_offset" conv=notrunc status=none
# Replace `cmp w0, #1` immediately after the first sizing-only
# unflatten_dt_nodes() returns with b 0x019c5230. Current raw Image offset
# 0x00c66ba4 -> target 0x019c5230, encoding 0x143579a3.
printf '\xa3\x79\x35\x14' | dd of="$image" bs=1 seek="$sizing_return_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
test "$(dd if="$image" bs=1 skip="$caller_checkpoint_offset" count=4 status=none | xxd -p)" = e00314aa
test "$(dd if="$image" bs=1 skip="$sizing_return_offset" count=4 status=none | xxd -p)" = a3793514
test "$(cmp -l "$base_image" "$image" | wc -l)" = 8

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r76 layout-preserving post-unflatten-sizing checkpoint

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The r75 caller checkpoint is
removed. Inside __unflatten_device_tree(), the instruction immediately after
the first sizing-only unflatten_dt_nodes(blob, NULL, ...) returns is replaced
with a direct branch to the already-audited PSCI reset trampoline.

Automatic reset proves the first FDT sizing pass returned. No reset localizes
the hang inside that first unflatten_dt_nodes() pass. This is a diagnostic
candidate, not a release kernel.
EOF

( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
