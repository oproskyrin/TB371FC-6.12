#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

source_dir=/root/tb371fc/linux-6.12-donor-r48
kernel_dir=/root/tb371fc/linux-6.12-donor-r49
base_out=/root/tb371fc/build-6.12-r38-watchdog-handoff
out_dir=/root/tb371fc/build-6.12-r49-tlb-flush-fix
package=/mnt/d/TB371FC-builds/linux-6.12.30-tb371fc-r49-tlb-flush-fix

test -d "$source_dir/.git"
test -f "$base_out/.config"
test ! -e "$kernel_dir" || { echo "Refusing to overwrite $kernel_dir" >&2; exit 1; }
test ! -e "$out_dir" || { echo "Refusing to overwrite $out_dir" >&2; exit 1; }
test ! -e "$package" || { echo "Refusing to overwrite $package" >&2; exit 1; }

cp -a --reflink=auto "$source_dir" "$kernel_dir"
mkdir -p "$out_dir" "$package"
cp "$base_out/.config" "$out_dir/.config"

# Root-cause hypothesis (2026-08-28 cold-boot pivot): map_mem()/paging_init()
# hangs only under kexec, not under a cold ABL boot of the identical Image.
# machine_kexec.c in the outgoing V56.6 4.19 kernel flushes the D-cache and
# I-cache for the kexec control-code buffer and the loaded kimage segments
# (Image/DTB/initramfs) via __flush_dcache_area/__flush_icache_range, but it
# never invalidates the TLB, and it never touches ordinary system RAM the
# incoming kernel reuses for its own page tables (map_mem's swapper_pg_dir
# allocations are not part of any kexec segment). Stale TLB entries left by
# the large, long-running 4.19 kernel are a plausible reason map_mem's page
# table construction faults only under kexec. r49 adds a single
# flush_tlb_all() (broadcast, inner-shareable invalidate-all) immediately
# before map_mem() runs -- a minimal, isolated fix touching only the 6.12
# kernel, not the V56.6 baseline -- and moves the checkpoint back to right
# after paging_init() returns (the same site r47 tested and did not reach),
# for an apples-to-apples comparison of the fix's effect.
python3 - "$kernel_dir/arch/arm64/mm/mmu.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

old_map_mem_checkpoint = (
	"void __init paging_init(void)\n"
	"{\n"
	"\tmap_mem(swapper_pg_dir);\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: map_mem() returned -- the full linear map for all\n"
	"\t * of RAM (built from current memblock regions) was created\n"
	"\t * without faulting. Single PSCI SYSTEM_RESET checkpoint (SMC\n"
	"\t * 0x84000009). */\n"
	"\tasm volatile(\n"
	"\t\t\"mov x1, xzr\\n\"\n"
	"\t\t\"mov x2, xzr\\n\"\n"
	"\t\t\"mov x3, xzr\\n\"\n"
	"\t\t\"mov x0, #0x09\\n\"\n"
	"\t\t\"movk x0, #0x8400, lsl #16\\n\"\n"
	"\t\t\"smc #0\\n\"\n"
	"\t\t::: \"x0\", \"x1\", \"x2\", \"x3\", \"memory\");\n"
	"#endif\n"
	"\n"
	"\tmemblock_allow_resize();\n"
)
assert text.count(old_map_mem_checkpoint) == 1, "r48 post-map_mem checkpoint not found or not unique"
fixed = (
	"void __init paging_init(void)\n"
	"{\n"
	"\t/* Candidate fix for a kexec-only hang in this function (never\n"
	"\t * reproduced on a cold ABL boot of the identical Image):\n"
	"\t * machine_kexec.c flushes the D/I-cache for the kexec control\n"
	"\t * buffer and loaded segments but never invalidates the TLB, and\n"
	"\t * never touches ordinary RAM this function reuses for its own\n"
	"\t * page tables. Clear any stale TLB state left by the outgoing\n"
	"\t * kernel before building new mappings. */\n"
	"\tflush_tlb_all();\n"
	"\n"
	"\tmap_mem(swapper_pg_dir);\n"
	"\n"
	"\tmemblock_allow_resize();\n"
)
text = text.replace(old_map_mem_checkpoint, fixed)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

python3 - "$kernel_dir/arch/arm64/kernel/setup.c" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

needle = (
	"\tpaging_init();\n"
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\ttb371fc_start_kernel_fb_marker(0xff8000ff, 30);\n"
	"#endif\n"
)
assert text.count(needle) == 1, "paging_init anchor not found or not unique"
replacement = (
	"\tpaging_init();\n"
	"#ifdef CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT\n"
	"\t/* Reached: paging_init() returned -- with the flush_tlb_all()\n"
	"\t * fix applied before map_mem(). Same checkpoint site r47 tested\n"
	"\t * without the fix (did not fire). Single PSCI SYSTEM_RESET\n"
	"\t * checkpoint (SMC 0x84000009). */\n"
	"\tasm volatile(\n"
	"\t\t\"mov x1, xzr\\n\"\n"
	"\t\t\"mov x2, xzr\\n\"\n"
	"\t\t\"mov x3, xzr\\n\"\n"
	"\t\t\"mov x0, #0x09\\n\"\n"
	"\t\t\"movk x0, #0x8400, lsl #16\\n\"\n"
	"\t\t\"smc #0\\n\"\n"
	"\t\t::: \"x0\", \"x1\", \"x2\", \"x3\", \"memory\");\n"
	"#endif\n"
	"#ifdef CONFIG_TB371FC_LATE_FB_MARKER\n"
	"\ttb371fc_start_kernel_fb_marker(0xff8000ff, 30);\n"
	"#endif\n"
)
text = text.replace(needle, replacement)
open(path, 'w', encoding='utf-8').write(text)
PYEOF

"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_EARLY_FB_MARKER
"$kernel_dir/scripts/config" --file "$out_dir/.config" --enable TB371FC_POST_MMU_RESET_CHECKPOINT
"$kernel_dir/scripts/config" --file "$out_dir/.config" --set-str LOCALVERSION '-tb371fc-r49-tlb-flush-fix'
make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 olddefconfig
grep -qx 'CONFIG_TB371FC_EARLY_FB_MARKER=y' "$out_dir/.config"
grep -qx 'CONFIG_TB371FC_POST_MMU_RESET_CHECKPOINT=y' "$out_dir/.config"
grep -q 'flush_tlb_all();' "$kernel_dir/arch/arm64/mm/mmu.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/mm/mmu.c"
test "$(grep -c 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c")" = "1"
grep -B10 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c" | grep -q 'paging_init() returned' \
	|| { grep -n -B12 'movk x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/setup.c"; false; }
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/init/main.c"
! grep -q 'movk.*x0, #0x8400, lsl #16' "$kernel_dir/arch/arm64/kernel/head.S"

make -C "$kernel_dir" O="$out_dir" ARCH=arm64 LLVM=-18 -j"$(nproc)" Image

install -m0644 "$out_dir/arch/arm64/boot/Image" "$package/Image"
install -m0644 "$out_dir/.config" "$package/config"
install -m0644 "$out_dir/System.map" "$package/System.map"
cat >"$package/BUILD-INFO.txt" <<'EOF'
TB371FC Linux 6.12.30 r49 TLB-invalidate candidate fix + post-paging_init checkpoint
- adds flush_tlb_all() immediately before map_mem() in paging_init()
  (arch/arm64/mm/mmu.c), on the hypothesis that stale TLB entries from the
  outgoing V56.6 4.19 kexec source kernel are why map_mem() only hangs under
  kexec and not under an identical cold ABL boot (2026-08-28 finding)
- checkpoint moved back to right after paging_init() returns (the r47 site)
  for a direct comparison: r47 without the fix did not reach this point
EOF
( cd "$package"; sha256sum Image config System.map BUILD-INFO.txt >SHA256SUMS; sha256sum -c SHA256SUMS )
stat -c 'Image=%s bytes' "$package/Image"
