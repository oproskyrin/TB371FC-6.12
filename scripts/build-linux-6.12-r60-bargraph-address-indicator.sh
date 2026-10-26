#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r59
kernel_dir=/root/tb371fc/linux-6.12-donor-r60
base_out=/root/tb371fc/build-6.12-r56-membank-region-fb-color-log
out_dir=/root/tb371fc/build-6.12-r60-bargraph-address-indicator
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r60-bargraph-address-indicator

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir"
cp "$base_out/.config" "$out_dir/.config"

# r56-r59's colour-based diagnostics proved too imprecise to read reliably
# from a phone photo (repeatedly ambiguous between visually-similar reds).
# r60 replaces colour entirely with an unambiguous bar graph: the 16-row
# diagnostic framebuffer band (already proven reachable/writable this
# session) is split into 8 equal-width columns, one per hex nibble of the
# region's start address (most-significant first, left to right); each
# column is filled white from the bottom up to (nibble_value + 1) rows out
# of 16 -- i.e. bar height directly encodes the nibble 0-15. This is
# readable by eye (or trivially measurable from a photo) with no colour
# perception or lighting/compression ambiguity at all.
python3 - "$kernel_dir/arch/arm64/kernel/setup.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

needle = (
	"static void __init tb371fc_map_fixmap_diagnostics(void)\n"
)
assert text.count(needle) == 1, "tb371fc_map_fixmap_diagnostics not found or not unique"
addition = (
	"void __init __no_sanitize_address\n"
	"tb371fc_diag_write_barcode(u64 start)\n"
	"{\n"
	"\tvolatile u32 *fb = tb371fc_fb_marker_base ?\n"
	"\t\t(volatile u32 *)tb371fc_fb_marker_base :\n"
	"\t\t(volatile u32 *)(unsigned long)TB371FC_FB_MARKER_PHYS;\n"
	"\tunsigned long rows = tb371fc_fb_marker_rows;\n"
	"\tunsigned long stride = TB371FC_FB_STRIDE_PIXELS;\n"
	"\tunsigned long seg = stride / 8;\n"
	"\tunsigned long total = stride * rows;\n"
	"\tvolatile u32 *p;\n"
	"\tint nibble, r;\n"
	"\tunsigned long c;\n"
	"\n"
	"\tp = fb;\n"
	"\twhile (total--)\n"
	"\t\t*p++ = 0xff000000u;\n"
	"\n"
	"\tfor (nibble = 0; nibble < 8; nibble++) {\n"
	"\t\tu32 val = (u32)((start >> ((7 - nibble) * 4)) & 0xf);\n"
	"\t\tunsigned long col_start = (unsigned long)nibble * seg;\n"
	"\t\tunsigned long bar_h = val + 1;\n"
	"\n"
	"\t\tfor (r = 0; r < (int)bar_h; r++) {\n"
	"\t\t\tunsigned long row = rows - 1 - (unsigned long)r;\n"
	"\n"
	"\t\t\tfor (c = 0; c < seg; c++)\n"
	"\t\t\t\tfb[row * stride + col_start + c] = 0xffffffffu;\n"
	"\t\t}\n"
	"\t}\n"
	"\tasm volatile(\"dsb sy\" ::: \"memory\");\n"
	"}\n"
	"\n" + needle
)
text = text.replace(needle, addition)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

python3 - "$kernel_dir/arch/arm64/mm/mmu.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old_marker = "\textern void tb371fc_start_kernel_fb_marker(u32 color, u32 stage);\n"
assert text.count(old_marker) == 1, "tb371fc_start_kernel_fb_marker extern decl not found or not unique"
text = text.replace(
	old_marker,
	old_marker + "\textern void tb371fc_diag_write_barcode(u64 start);\n"
)

old_switch_block = (
	"\t\t{\n"
	"\t\t\tu32 diag_color;\n"
	"\t\t\tswitch ((u32)start) {\n"
	"\t\t\tcase 0x80700000: diag_color = 0xffffffffu; break; /* white:  xbl_aop */\n"
	"\t\t\tcase 0x80860000: diag_color = 0xffff0000u; break; /* red:    cmd_db */\n"
	"\t\t\tcase 0x80880000: diag_color = 0xff00ff00u; break; /* green:  xbl_uefi_log */\n"
	"\t\t\tcase 0x80900000: diag_color = 0xff0000ffu; break; /* blue:   smem */\n"
	"\t\t\tcase 0x80b00000: diag_color = 0xffffff00u; break; /* yellow: removed_region */\n"
	"\t\t\tcase 0x86200000: diag_color = 0xffff00ffu; break; /* magenta:pil_camera */\n"
	"\t\t\tcase 0x86700000: diag_color = 0xff00ffffu; break; /* cyan:   pil_wlan_fw */\n"
	"\t\t\tcase 0x86800000: diag_color = 0xffff8000u; break; /* orange: pil_ipa_fw */\n"
	"\t\t\tcase 0x86810000: diag_color = 0xffff0080u; break; /* pink:   pil_ipa_gsi */\n"
	"\t\t\tcase 0x8681a000: diag_color = 0xff80ff00u; break; /* chartreuse: pil_gpu */\n"
	"\t\t\tcase 0x86900000: diag_color = 0xff00ff80u; break; /* spring-green: pil_npu */\n"
	"\t\t\tcase 0x86e00000: diag_color = 0xff0080ffu; break; /* azure:  pil_video */\n"
	"\t\t\tcase 0x87300000: diag_color = 0xff8000ffu; break; /* violet: pil_cvp */\n"
	"\t\t\tcase 0x87800000: diag_color = 0xff808080u; break; /* gray:   pil_cdsp */\n"
	"\t\t\tcase 0x88c00000: diag_color = 0xffc0c0c0u; break; /* light-gray: pil_slpi */\n"
	"\t\t\tcase 0x8a100000: diag_color = 0xff804000u; break; /* brown:  pil_adsp */\n"
	"\t\t\tcase 0x8be00000: diag_color = 0xff008080u; break; /* teal:   pil_spss */\n"
	"\t\t\tcase 0x8bf00000: diag_color = 0xff408040u; break; /* dark-spring-green: cdsp_secure_heap */\n"
	"\t\t\tcase 0xb0000000: diag_color = 0xff400080u; break; /* dark-violet: boot_log_region (should not recur) */\n"
	"\t\t\tdefault:\n"
	"\t\t\t\tdiag_color = 0xff000000u |\n"
	"\t\t\t\t\t(((u32)(start >> 24) & 0xff) << 16) |\n"
	"\t\t\t\t\t(((u32)(start >> 16) & 0xff) << 8) |\n"
	"\t\t\t\t\t((u32)(start >> 8) & 0xff);\n"
	"\t\t\t}\n"
	"\t\t\ttb371fc_start_kernel_fb_marker(diag_color, 0x9f);\n"
	"\t\t}\n"
)
assert text.count(old_switch_block) == 1, "r59 diag_color switch block not found or not unique"
replacement_block = "\t\ttb371fc_diag_write_barcode(start);\n"
text = text.replace(old_switch_block, replacement_block)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_LATE_FB_MARKER=y' "$out_dir/.config"
grep -q 'tb371fc_diag_write_barcode' "$kernel_dir/arch/arm64/mm/mmu.c"
grep -q 'tb371fc_diag_write_barcode' "$kernel_dir/arch/arm64/kernel/setup.c"
! grep -q 'diag_color' "$kernel_dir/arch/arm64/mm/mmu.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r60 bar-graph address diagnostic
- r56-r59's colour-based diagnostics were repeatedly too ambiguous to read
  reliably from a phone photo
- r60 replaces colour with an unambiguous 8-column bar graph: one bar per
  hex nibble of the region start address (MSB first, left to right), each
  bar filled white from the bottom up to (nibble value + 1) rows out of 16
  -- read the address directly off the bar heights, no colour perception
  needed
- reuses r57's DTB unchanged (boot_log_region no-map reservation)
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
