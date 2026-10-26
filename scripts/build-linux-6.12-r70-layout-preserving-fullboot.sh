#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

base=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r68-embedded-pgtable-pool
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r70-embedded-pgtable-pool
base_image=$base/Image
image=$package/Image
base_sha=09c1b144772bcc37644bf62774549bf4bd8eb01b22a6aba265d641227845a8ec
sequence_offset=$((0x019c5224))
patch_offset=$((0x019c5238))
before=e1031faae2031faae3031faa200180d20080b0f2030000d4
after=e1031faae2031faae3031faa200180d20080b0f21f2003d5

test -f "$base_image"
printf '%s  %s\n' "$base_sha" "$base_image" | sha256sum -c -
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

actual_before=$(dd if="$base_image" bs=1 skip="$sequence_offset" count=24 status=none | xxd -p -c 256)
test "$actual_before" = "$before" || {
  echo "Pinned r68 checkpoint sequence mismatch: $actual_before" >&2
  exit 1
}

mkdir -p "$package"
cp --reflink=auto "$base_image" "$image"
cp "$base/config" "$package/config"
cp "$base/System.map" "$package/System.map"

# AArch64 encodings, little endian:
#   smc #0 = 03 00 00 d4
#   nop    = 1f 20 03 d5
printf '\x1f\x20\x03\xd5' | dd of="$image" bs=1 seek="$patch_offset" conv=notrunc status=none

test "$(stat -c %s "$image")" = "$(stat -c %s "$base_image")"
actual_after=$(dd if="$image" bs=1 skip="$sequence_offset" count=24 status=none | xxd -p -c 256)
test "$actual_after" = "$after"
test "$(cmp -l "$base_image" "$image" | wc -l)" = 4
cmp -n "$patch_offset" "$base_image" "$image"
suffix_offset=$((patch_offset + 4))
cmp -i "$suffix_offset:$suffix_offset" "$base_image" "$image"

cat >"$package/BUILD-INFO.txt" <<EOF
TB371FC Linux 6.12.30 r70 layout-preserving full-boot experiment

Base Image SHA-256: $base_sha
Base Image: $base_image

No compilation or relinking was performed. The complete hardware-proven r68
Image layout is retained. Exactly four bytes at Image offset 0x019c5238 were
changed:

  03 00 00 d4  AArch64 smc #0
  1f 20 03 d5  AArch64 nop

The five register-setup instructions preceding the checkpoint remain in place
and are harmless. Every byte before and after this single instruction was
verified identical with cmp. This bypasses the r68 diagnostic PSCI reset while
preserving all addresses and timing far more closely than the relinked r69.

The embedded 1 MiB early page-table pool, framebuffer markers and localversion
remain exactly those of r68 by design. This is a diagnostic candidate, not a
release kernel.
EOF

printf '%s\n' "$actual_before" >"$package/CHECKPOINT-BEFORE.hex"
printf '%s\n' "$actual_after" >"$package/CHECKPOINT-AFTER.hex"
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt \
    CHECKPOINT-BEFORE.hex CHECKPOINT-AFTER.hex >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$image"
sha256sum "$image"
