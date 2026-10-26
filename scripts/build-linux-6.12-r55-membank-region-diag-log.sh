#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r47
kernel_dir=/root/tb371fc/linux-6.12-donor-r55
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r55-membank-region-diag-log
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r55-membank-region-diag-log

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# r53/r54 proved the fault is inside the VERY FIRST __map_memblock() call of
# the for_each_mem_range() loop in map_mem(). Rather than continue blind
# bisection (one bit of information -- fired/hung -- per physical
# power-cycle), r55 uses a smarter technique: the pre-existing
# TB371FC_LATE_FB_MARKER infrastructure already early_ioremap()s two fixed
# physical scratch addresses (TB371FC_STAGE_WORD_PHYS 0x9d5ff000 and a
# backup at 0xb007f000, inside the stock boot_log_region) that survive a
# warm PSCI reset and can be read back afterwards via the V56.6 first
# stage's own `devmem` (confirmed present in its busybox). This Kconfig
# symbol previously had no Kconfig prompt at all (always compiled out); r55
# adds one and adds a new tb371fc_diag_write_region() helper that records
# the CURRENT loop iteration index and the memblock region's [start, end)
# into that scratch memory, called right before every __map_memblock()
# call. No PSCI reset is added -- execute is expected to hang exactly as
# r54 did (requiring the same physical power-cycle as always), but this
# time the scratch memory holds the index/address of the LAST region that
# was being mapped when it hung, readable in one shot after recovery
# instead of one more bisection revision.
python3 - "$kernel_dir/arch/arm64/Kconfig.debug" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
needle = "source \"drivers/hwtracing/coresight/Kconfig\"\n"
assert text.count(needle) == 1, "coresight Kconfig source line not found or not unique"
addition = (
	needle +
	"\n"
	"config TB371FC_LATE_FB_MARKER\n"
	"\tbool \"TB371FC staged post-MMU framebuffer/scratch markers\"\n"
	"\tdefault n\n"
	"\thelp\n"
	"\t  Paint diagnostic colour bands and record boot-stage/region\n"
	"\t  diagnostics in fixed physical scratch memory (backed by\n"
	"\t  early_ioremap, valid once the MMU is active) that survives a\n"
	"\t  warm PSCI reset and can be read back afterwards. For early\n"
	"\t  boot localization only; must remain disabled in production\n"
	"\t  kernels.\n"
)
text = text.replace(needle, addition)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

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
	"tb371fc_diag_write_region(u32 index, u64 start, u64 end)\n"
	"{\n"
	"\tvolatile u32 *stage_word = tb371fc_stage_word_base ?\n"
	"\t\t(volatile u32 *)tb371fc_stage_word_base :\n"
	"\t\t(volatile u32 *)(unsigned long)TB371FC_STAGE_WORD_PHYS;\n"
	"\tvolatile u32 *stage_backup = tb371fc_stage_backup_base ?\n"
	"\t\t(volatile u32 *)tb371fc_stage_backup_base :\n"
	"\t\t(volatile u32 *)(unsigned long)TB371FC_STAGE_BACKUP_PHYS;\n"
	"\tu32 magic = 0x4d454d31; /* 'MEM1' */\n"
	"\tu32 words[6];\n"
	"\tint i;\n"
	"\n"
	"\twords[0] = magic;\n"
	"\twords[1] = index;\n"
	"\twords[2] = (u32)(start & 0xffffffffUL);\n"
	"\twords[3] = (u32)(start >> 32);\n"
	"\twords[4] = (u32)(end & 0xffffffffUL);\n"
	"\twords[5] = (u32)(end >> 32);\n"
	"\tfor (i = 0; i < 6; i++) {\n"
	"\t\tstage_word[16 + i] = words[i];\n"
	"\t\tstage_backup[16 + i] = words[i];\n"
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

old_loop = (
	"\t/* map all the memory banks */\n"
	"\tfor_each_mem_range(i, &start, &end) {\n"
	"\t\tif (start >= end)\n"
	"\t\t\tbreak;\n"
	"\t\t/*\n"
	"\t\t * The linear map must allow allocation tags reading/writing\n"
	"\t\t * if MTE is present. Otherwise, it has the same attributes as\n"
	"\t\t * PAGE_KERNEL.\n"
	"\t\t */\n"
	"\t\t__map_memblock(pgdp, start, end, pgprot_tagged(PAGE_KERNEL),\n"
	"\t\t\t       flags);\n"
	"\t}\n"
)
assert text.count(old_loop) == 1, "for_each_mem_range membank loop not found or not unique"
replacement = (
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
	"\t\t/*\n"
	"\t\t * The linear map must allow allocation tags reading/writing\n"
	"\t\t * if MTE is present. Otherwise, it has the same attributes as\n"
	"\t\t * PAGE_KERNEL.\n"
	"\t\t */\n"
	"\t\t__map_memblock(pgdp, start, end, pgprot_tagged(PAGE_KERNEL),\n"
	"\t\t\t       flags);\n"
	"\t}\n"
)
text = text.replace(old_loop, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_LATE_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --disable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r55-membank-region-diag-log'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_LATE_FB_MARKER=y' "$out_dir/.config"
grep -q 'tb371fc_diag_write_region' "$kernel_dir/arch/arm64/mm/mmu.c"
grep -q 'tb371fc_diag_write_region' "$kernel_dir/arch/arm64/kernel/setup.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r55 membank-region physical-scratch diagnostic log
- r53/r54 proved the fault is inside the very first __map_memblock() call
  of the for_each_mem_range() loop in map_mem()
- adds a Kconfig prompt for the previously-dead TB371FC_LATE_FB_MARKER
  infrastructure and a new tb371fc_diag_write_region() helper that records
  the current loop iteration index and memblock region [start, end) into
  fixed physical scratch memory (0x9d5ff000, backup 0xb007f000 inside
  boot_log_region) that survives a warm PSCI reset
- called right before every __map_memblock() call in the loop -- no PSCI
  reset added; execute is expected to hang exactly as r54 did, requiring
  the same physical power-cycle, but the scratch memory then holds the
  index/address of the LAST region being mapped when it hung
- read back after recovery via: devmem 0x9d5ff040 32; devmem 0x9d5ff044 32;
  devmem 0x9d5ff048 32; devmem 0x9d5ff04c 32; devmem 0x9d5ff050 32;
  devmem 0x9d5ff054 32  (word offsets 16-21: magic, index, start_lo,
  start_hi, end_lo, end_hi)
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
