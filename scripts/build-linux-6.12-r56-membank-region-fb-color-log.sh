#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r55
kernel_dir=/root/tb371fc/linux-6.12-donor-r56
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r56-membank-region-fb-color-log
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r56-membank-region-fb-color-log

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r55's physical-scratch diagnostic write (tb371fc_diag_write_region) is
# confirmed correct in principle -- the hang reproduced exactly as r54
# predicted, and the pre-existing TB371FC_LATE_FB_MARKER stages (now
# enabled for the first time this session) visibly painted further than
# any previous build (photo showed a new pink/magenta top stripe over the
# usual wide yellow-green band, both further boot progress than the old
# frozen orange stripe). But V56.6's 4.19 kernel has /dev/mem blocked for
# ordinary RAM (STRICT_DEVMEM): `mknod` succeeds, but `devmem` fails with
# "No such device or address" on every read -- the physical scratch words
# cannot be read back this way.
#
# r56 keeps r55's scratch-memory write (harmless, kept for completeness)
# and ADDS a second, already-proven-working channel: paint the region's
# start address directly as an RGB colour into the SAME 16-row diagnostic
# framebuffer band the late-stage markers already use (confirmed visible
# in the r55 photo), overwriting whatever the last setup_arch() stage
# marker left there. Called every loop iteration, so whichever iteration
# was in progress when it hung is what remains on screen -- readable from
# a single photo, no /dev/mem needed.
# Colour encoding (0xFFRRGGBB): R = bits[31:24] of start, G = bits[23:16],
# B = bits[15:8] (start is at least 4 KiB aligned, so the low byte is
# always 0 and is dropped).
python3 - "$kernel_dir/arch/arm64/mm/mmu.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old = (
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\textern void tb371fc_diag_write_region(u32 index, u64 start, u64 end);\n"
	"\tu32 tb371fc_diag_idx = 0;\n"
	"#endif\n"
	"\t/* map all the memory banks */\n"
	"\tfor_each_mem_range(i, &start, &end) {\n"
	"\t\tif (start >= end)\n"
	"\t\t\tbreak;\n"
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\t\ttb371fc_diag_write_region(tb371fc_diag_idx++, start, end);\n"
	"#endif\n"
)
assert text.count(old) == 1, "r55 diag-write loop entry not found or not unique"
replacement = (
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\textern void tb371fc_diag_write_region(u32 index, u64 start, u64 end);\n"
	"\textern void tb371fc_start_kernel_fb_marker(u32 color, u32 stage);\n"
	"\tu32 tb371fc_diag_idx = 0;\n"
	"#endif\n"
	"\t/* map all the memory banks */\n"
	"\tfor_each_mem_range(i, &start, &end) {\n"
	"\t\tif (start >= end)\n"
	"\t\t\tbreak;\n"
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\t\ttb371fc_diag_write_region(tb371fc_diag_idx++, start, end);\n"
	"\t\t{\n"
	"\t\t\tu32 diag_color = 0xff000000u |\n"
	"\t\t\t\t(((u32)(start >> 24) & 0xff) << 16) |\n"
	"\t\t\t\t(((u32)(start >> 16) & 0xff) << 8) |\n"
	"\t\t\t\t((u32)(start >> 8) & 0xff);\n"
	"\t\t\ttb371fc_start_kernel_fb_marker(diag_color, 0x9f);\n"
	"\t\t}\n"
	"#endif\n"
)
text = text.replace(old, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_LATE_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --disable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r56-membank-region-fb-color-log'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_LATE_FB_MARKER=y' "$out_dir/.config"
grep -q 'diag_color' "$kernel_dir/arch/arm64/mm/mmu.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r56 membank-region framebuffer-colour diagnostic
- r55's physical-scratch diag write is blocked from read-back: V56.6 4.19
  has /dev/mem access to ordinary RAM denied (STRICT_DEVMEM); devmem fails
  with "No such device or address" on every read despite mknod succeeding
- r56 adds a second, already-proven-working channel: paints the current
  memblock region's start address as an RGB colour (0xFFRRGGBB, R/G/B =
  bits[31:24]/[23:16]/[15:8] of start) into the same 16-row diagnostic
  framebuffer band the late-stage markers already use, called right before
  every __map_memblock() -- whichever iteration is in progress when it
  hangs is what remains visible, readable from a single photo
- keeps r55's scratch-memory write too (harmless)
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
