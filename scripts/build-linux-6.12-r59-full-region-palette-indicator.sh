#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r58
kernel_dir=/root/tb371fc/linux-6.12-donor-r59
base_out=/root/tb371fc/build-6.12-r56-membank-region-fb-color-log
out_dir=/root/tb371fc/build-6.12-r59-full-region-palette-indicator
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r59-full-region-palette-indicator

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir"
cp "$base_out/.config" "$out_dir/.config"

# r58 confirmed the region hit when it hangs is NOT exactly boot_log_region
# any more (colour was reddish, not the unmistakable pure blue exact-match
# indicator) -- boot_log_region's no-map reservation worked as predicted by
# should_skip_region() in mm/memblock.c. But the plain 0xFFRRGGBB address
# encoding is too imprecise for a phone photo to distinguish between
# visually-similar high-R candidates (e.g. 0x8be00000 vs 0x8bf00000 vs
# 0x8a100000). r59 replaces the encoding with an exact-match lookup against
# ALL remaining stock PIL/firmware candidate addresses, each assigned a
# maximally distinct, unmistakable flat colour from a curated palette
# (pure/extreme RGB combinations); the plain 0xFFRRGGBB encoding remains
# only as a fallback for a genuinely unexpected address (e.g. something
# beyond the known candidate list, which would mean the fault moved
# entirely outside the previously reserved-in-stock PIL/firmware range).
python3 - "$kernel_dir/arch/arm64/mm/mmu.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old = (
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
assert text.count(old) == 1, "r58 diag_color block not found or not unique"
replacement = (
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
text = text.replace(old, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig >/dev/null
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_LATE_FB_MARKER=y' "$out_dir/.config"
grep -q '0x8be00000' "$kernel_dir/arch/arm64/mm/mmu.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

mkdir -p "$package"
install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r59 full-region palette indicator
- r58 confirmed boot_log_region's no-map reservation worked: colour was
  NOT the unmistakable pure blue exact-match, meaning the loop no longer
  hits 0xb0000000
- r59 replaces the ambiguous 0xFFRRGGBB encoding with an exact-match
  lookup against all remaining stock PIL/firmware candidate addresses,
  each assigned a maximally distinct flat colour (white/red/green/blue/
  yellow/magenta/cyan/orange/pink/chartreuse/spring-green/azure/violet/
  gray/light-gray/brown/teal/dark-spring-green/dark-violet); falls back to
  the plain address encoding for a genuinely unexpected region
- reuses r57's DTB unchanged (boot_log_region no-map reservation)
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
