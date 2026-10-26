#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r57
kernel_dir=/root/tb371fc/linux-6.12-donor-r58
base_out=/root/tb371fc/build-6.12-r56-membank-region-fb-color-log
out_dir=/root/tb371fc/build-6.12-r58-boot-log-exact-match-indicator
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r58-boot-log-exact-match-indicator

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir"
cp "$base_out/.config" "$out_dir/.config"

# r57's DTB decompiles correctly with boot_log_region (0xb0000000) flagged
# no-map, and arm64's should_skip_region() in mm/memblock.c confirms
# for_each_mem_range() (used by map_mem(), no MEMBLOCK_NOMAP in its flags)
# does skip memblock regions with MEMBLOCK_NOMAP set -- so in principle
# r57 should have excluded boot_log_region from the loop entirely. But the
# owner's photo after the r57 hardware test read back the same colour as
# r56 (both "reddish"). r57's encoding drops the low byte and only uses 8
# bits per channel, and 0xb0000000 (boot_log_region, R=0xb0) is visually
# close to neighbouring candidates like 0x8be00000/0x8bf00000 (R=0x8b) in a
# phone photo -- too ambiguous to be certain whether the SAME region is
# still being hit or whether it moved to a visually-similar neighbour.
#
# r58 removes the ambiguity with an unmistakable boolean indicator: paint
# pure blue (0xFF0000FF) if the region about to be mapped is EXACTLY
# boot_log_region's start address (0xb0000000); otherwise use the same
# 0xFFRRGGBB address encoding as r56/r57. Pure blue definitively confirms
# the DTS reservation had no effect on the loop; any other colour
# definitively confirms it moved past boot_log_region to a different
# region.
python3 - "$kernel_dir/arch/arm64/mm/mmu.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old = (
	"\t\t{\n"
	"\t\t\tu32 diag_color = 0xff000000u |\n"
	"\t\t\t\t(((u32)(start >> 24) & 0xff) << 16) |\n"
	"\t\t\t\t(((u32)(start >> 16) & 0xff) << 8) |\n"
	"\t\t\t\t((u32)(start >> 8) & 0xff);\n"
	"\t\t\ttb371fc_start_kernel_fb_marker(diag_color, 0x9f);\n"
	"\t\t}\n"
)
assert text.count(old) == 1, "r56 diag_color block not found or not unique"
replacement = (
	"\t\t{\n"
	"\t\t\tu32 diag_color;\n"
	"\t\t\tif (start == 0xb0000000ULL)\n"
	"\t\t\t\tdiag_color = 0xff0000ffu; /* exact boot_log_region match */\n"
	"\t\t\telse\n"
	"\t\t\t\tdiag_color = 0xff000000u |\n"
	"\t\t\t\t\t(((u32)(start >> 24) & 0xff) << 16) |\n"
	"\t\t\t\t\t(((u32)(start >> 16) & 0xff) << 8) |\n"
	"\t\t\t\t\t((u32)(start >> 8) & 0xff);\n"
	"\t\t\ttb371fc_start_kernel_fb_marker(diag_color, 0x9f);\n"
	"\t\t}\n"
)
text = text.replace(old, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_LATE_FB_MARKER=y' "$out_dir/.config"
grep -q '0xb0000000ULL' "$kernel_dir/arch/arm64/mm/mmu.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r58 boot_log_region exact-match indicator
- r57's DTB correctly no-maps boot_log_region (0xb0000000) and
  should_skip_region() in mm/memblock.c confirms for_each_mem_range()
  should skip MEMBLOCK_NOMAP regions -- but the r57 hardware photo read
  back the same ambiguous reddish colour as r56
- r58 paints pure blue (0xFF0000FF) if the region about to be mapped is
  EXACTLY 0xb0000000 (boot_log_region); otherwise the same 0xFFRRGGBB
  address encoding as r56/r57. Removes colour ambiguity between
  boot_log_region and visually-similar neighbouring candidate addresses.
- reuses r57's DTB unchanged (boot_log_region no-map reservation)
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
